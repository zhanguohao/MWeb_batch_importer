#!/bin/bash


# -------------------------------
# 参数
# 
docsSrcDir=$1
mWebBase=$2
mWebDocsDir=${mWebBase}/docs
mWebDb=${mWebBase}/mainlib.db



# -------------------------------
#  获取时间戳长度
#  $1 长度            可选
# 
function getUUID(){
    local length=$1
    local uuid=0
    if [ -z ${length} ]
    then
        length=14
    elif [[ ${length} < 1 ]]; then
        length=14
    fi

    uuid=`gdate +%s%N | cut -c1-${length}`
    echo ${uuid}
}

# -------------------------------
#  插入一个分类并且获取序号
#  $1 分类名称            必选
#  $2 父分类的uuid        可选
# 
function insertNewCatAndGetSeq() {
    
    local catName=$1
    local parentCatUuid=$2
    local catUuid=000
    local currentCatSeq=000
    local newCatSeq=001
    local currentSortSeq=000
    local newSortSeq=001
    local uuid=0
    local pid=0
    
    if [ -z "${catName}" ]
    then
        catUuid=${topCatUuid}
        return;
    fi
    
    if [ -z "${parentCatUuid}" ]
    then
        catUuid=$(sqlite3 ${mWebDb} "select uuid from cat where name='${catName}'")
        pid=0
    else
        catUuid=$(sqlite3 ${mWebDb} "select uuid from cat where name='${catName}' and pid=${parentCatUuid}")
        pid=${parentCatUuid}
    fi
    
    if [ -n "${catUuid}" ]
    then
        # printf "分类已存在，不需创建"
        # printf "catUuid=${catUuid}"
        echo ${catUuid}
        return
    fi
    
    currentCatSeq=$(sqlite3 ${mWebDb} "select seq from sqlite_sequence where name='cat'")
    newCatSeq=$((currentCatSeq+1))
    # printf "newCatSeq=${newCatSeq}"
    
    sqlite3 ${mWebDb} "update sqlite_sequence set seq=${newCatSeq} where name='cat'"
    
    currentSortSeq=$(sqlite3 ${mWebDb} "select max(sort) from cat")
    newSortSeq=$((currentSortSeq+1))
    # printf "newSortSeq=${newSortSeq}"
    
    uuid=$(getUUID)

    
    sqlite3 ${mWebDb} "insert into cat(id, pid, uuid, name, docName, catType, sort, sortType, siteURL, siteSkinName, siteLastBuildDate, siteBuildPath, siteFavicon, siteLogo, siteDateFormat, sitePageSize, siteListTextNum, siteName, siteDes, siteShareCode, siteHeader, siteOther, siteMainMenuData, siteExtDef, siteExtValue, sitePostExtDef, siteEnableLaTeX, siteEnableChart) values(${newCatSeq}, ${pid}, ${uuid}, '${catName}', '', 12, ${newSortSeq}, 0, '', '', 0, '', '', '', '', 0, 0, '', '', '', '', '', '', '', '', '', 0, 0)"
    # printf "新分类已创建"
    # printf "分类名: ${catName}"
    
    catUuid=$(sqlite3 ${mWebDb} "select uuid from cat where name='${catName}'" | sed -n '1p')
    # printf "catUuid=${catUuid}"

    # echo 传递uuid
    echo ${catUuid}
    return

}

# -------------------------------
#  插入一个Tag并获取序号
#  $1 Tag名称            必选
# 
function insertNewTagAndGetSeq() {
    local tagName=$1
    local tagId=0
    local currentTagSeq=000
    local newTagSeq=001

    tagId=$(sqlite3 ${mWebDb} "select id from tag where name='${tagName}'")
    
    if [ -n "${tagId}" ]
    then
        # printf "Tag已存在，不需创建"
        # printf "tagId=${tagId}"
        echo ${tagId}
        return
    fi
    
    currentTagSeq=$(sqlite3 ${mWebDb} "select seq from sqlite_sequence where name='tag'")
    newTagSeq=$((currentTagSeq+1))
    # printf "newTagSeq=${newTagSeq}"
    
    sqlite3 ${mWebDb} "update sqlite_sequence set seq=${newTagSeq} where name='${tagName}'"
    sqlite3 ${mWebDb} "insert into tag(id, name) values(${newTagSeq}, '${tagName}')"
    
    tagId=$(sqlite3 ${mWebDb} "select id from tag where name='${tagName}'" | sed -n '1p')
    # printf "tagId=${tagId}"
    echo ${tagId}
}

# -------------------------------
#  数据库中插入新文章
#  $1 文章id            必选
#
function insertNewArticleToDatabse() {
    local aid=$1
    local currentSeq=000
    local newSeq=001
    local dateAddModify=$(echo ${aid} | cut -c1-10)
    
    currentSeq=$(sqlite3 ${mWebDb} "select seq from sqlite_sequence where name='article'")
    newSeq=$((currentSeq+1))
    # dateAddModify=$(echo ${aid} | cut -c1-10)
    
    sqlite3 ${mWebDb} "update sqlite_sequence set seq=${newSeq} where name='article'"
    sqlite3 ${mWebDb} "insert into article(id, uuid, type, state, sort, dateAdd, dateModif, dateArt, docName, otherMedia, buildResource, postExtValue) values(${newSeq}, ${aid}, 0, 1, ${aid}, ${dateAddModify}, ${dateAddModify}, ${dateAddModify}, '', '', '', '')"

}

# -------------------------------
#  数据库中设置文章分类
# $1 articleId      文章id   必选
# $2 categoryUuid   分类id   必选
#
function insertNewCatArticleToDatabse() {
    
    local aid=$1
    local catUuid=$2
    local currentSeq=000
    local newSeq=001
    
    currentSeq=$(sqlite3 ${mWebDb} "select seq from sqlite_sequence where name='cat_article'")
    newSeq=$((currentSeq+1))
    
    sqlite3 ${mWebDb} "update sqlite_sequence set seq=${newSeq} where name='cat_article'"
    sqlite3 ${mWebDb} "insert into cat_article(id, rid, aid) values(${newSeq}, ${catUuid}, ${aid})"
}

# -------------------------------
#  数据库中设置文章Tag
# $1 articleId      文章id   必选
# $2 categoryUuid   TagId   必选
#
function insertNewTagArticleToDatabse() {
    
    local aid=$1
    local tagId=$2
    local currentSeq=000
    local newSeq=001
    
    currentSeq=$(sqlite3 ${mWebDb} "select seq from sqlite_sequence where name='tag_article'")
    newSeq=$((currentSeq+1))
    
    sqlite3 ${mWebDb} "update sqlite_sequence set seq=${newSeq} where name='tag_article'"
    sqlite3 ${mWebDb} "insert into tag_article(id, rid, aid) values(${newSeq}, ${tagId}, ${aid})"
}


# -------------------------------
# 递归遍历文件夹
# $1：文件夹路径
# $2：父文件夹id(不填默认为0，即根目录)
# 
function recusive_dir(){
    local path=$1
    local p_cat_uuid=$2
    local cur_cat=`basename ${path}`
    local cur_cat_uuid=0

    if [ -z $p_cat_uuid ]
    then
        p_cat_uuid=0
    fi

    # 数据库中创建当前的目录的分类，并且得到相应的分类id
    cur_cat_uuid=$(insertNewCatAndGetSeq ${cur_cat} ${p_cat_uuid})

    for file in `ls "${path}"`
    do
        if [ -d "${path}/${file}" ]
        then
            recusive_dir "${path}/${file}" ${cur_cat_uuid}
        else
            printf "Handling with ${path}/${file}\n"
            # md文档，拷贝到目的文件夹并将数据插入数据库
            newFileName=$(getUUID 14)
            cp "${path}/${file}" "${mWebDocsDir}/${newFileName}.md"
            insertNewArticleToDatabse ${newFileName}
            insertNewCatArticleToDatabse ${newFileName} ${cur_cat_uuid}
            printf "Done with ${path}/${file}\n"
        fi
    done
}


# -------------------------------
# 提示信息
# 
function prompt(){
    printf "请输入正确的参数："
    printf "[file].sh 导入文件夹 Mweb库目录"
}


# -------------------------------
# 判断参数
# 
if [[ $# == 2 ]] 
then
    if [ -d $docsSrcDir -a -d $mWebBase ]
    then
        recusive_dir $docsSrcDir
    else
        prompt
    fi
else
    prompt
fi





