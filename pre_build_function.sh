#!/bin/bash


# ----------------------------------------------------------------------
# name:         pre_build_function.sh
# version:      1.0.0(100)
# createTime:   2018-08-30
# description:  打包之前处理函数文件
# author:       liboy
# email:        779385288@qq.com
# github:       https://github.com/liboy/LBAutoPackingShell
# ----------------------------------------------------------------------

# ********************* user_config.plist *********************
#读取   ShellUserConfigPlist.plist文件
function printPathPlist() {
    echo `$CMD_PlistBuddy -c "Print :${1}" ${ShellUserConfigPlist}`
}
#写入   ShellUserConfigPlist.plist文件
function setPathPlist() {
    echo `$CMD_PlistBuddy -c 'Set :'${1}' "'${2}'"' ${ShellUserConfigPlist}`
}

# ********************* 读资源文件 *********************
function printResource_Config() {
    # 脚本资源里Config.plist文件路径
    local configPlistPath="${Tmp_resource_path}/Config.plist"
    echo `$CMD_PlistBuddy -c "Print :${1}" ${configPlistPath}`
}
function setResource_Config() {
    local configPlistPath="${Tmp_resource_path}/Config.plist"
    echo `$CMD_PlistBuddy -c 'Set :'${1}' "'${2}'"' $configPlistPath`
}

function setProject_Config() {
    echo `$CMD_PlistBuddy -c 'Set :'${1}' "'${2}'"' ${project_config_plist}`
}

# ********************* 项目中Info.plist配置 *********************

function printProject_Info() {
    # 项目里Info.plist文件路径
    local project_info_plist="${project_build_path}/${project_name}/Info.plist"
    echo `$CMD_PlistBuddy -c "Print :${1}" ${project_info_plist}`
}

function setProject_Info() {
    # 项目里Info.plist文件路径
    local project_info_plist="${project_build_path}/${project_name}/Info.plist"
    echo `$CMD_PlistBuddy -c 'Set :'${1}' "'${2}'"' ${project_info_plist}`
}

#设置Info.plist文件的构建版本号
function setBuildVersion () {
    local infoPlistFile=$1
    local buildVersion=$2
    if [[ ! -f "$infoPlistFile" ]]; then
        exit 1
    fi
    $CMD_PlistBuddy -c "Set :CFBundleVersion $buildVersion" "$infoPlistFile"
}


# 判断 数组是否包含对应元素
function contains() {
    # $#:参数个数
    # ${!n} 根据索引获取对应参数
    local n=$#
    for ((i=1;i < n;i++)) {
        if [ "${!i}" == "${!n}" ]; then
        echo "y"
        return 0
        fi
    }
    echo "n"
    return 1
}

## 拷贝项目到打包目录
function copyProjectFile() {

    if [ -d $project_build_path ]; then
        logit "【工程文件】删除之前工程文件 ${project_build_path}"
        rm -rf "$project_build_path"
        if [ $? -eq 0 ];then
            logit "【工程文件】删除成功 "
        else
            errorExit "原有工程删除失败！"
        fi
    fi
    logit "【工程文件】拷贝项目文件中,请稍等... "
    cp -rf ${project_source_path} $project_build_path
    if [ $? -eq 0 ];then
        logit "【工程文件】拷贝成功"
    else
        errorExit "工程文件拷贝失败"
    fi
}

## 生成并替换AppIcon
function createAppIcon() {

    # ************* 安装Blade ************* https://github.vimcom/jondot/blade
    # blade --help 查看命令
    # -s Icon( *注意：1024*1024,无alph,png格式)
    # -t AppIcon.appiconset里的Contents.json文件
    # -o 输出路径 AppIcon.appiconset
    # -c 覆盖旧的Contents.json文件

    ResourceIconFilePath="$Tmp_resource_path/icon.png"
    if [ ! -f "${ResourceIconFilePath}" ]; then
        errorExit "${ResourceIconFilePath}不存在"
    fi 
    project_icon_path="${project_build_path}/${project_name}/Assets.xcassets/AppIcon.appiconset"
    if [ ! -d $project_icon_path ];then
        errorExit "${project_icon_path}不存在"
    fi

    logit "【生成AppIcon】生成AppIcon中..."
    blade --verbose -s "${ResourceIconFilePath}" -t "${project_icon_path}/Contents.json" -o "${project_icon_path}" -c
    if [ $? -eq 0 ];then
        logit "【生成AppIcon】生成成功"
    else
        errorExit "生成AppIcon失败"
    fi

}

## 替换项目启动图
function replaceLaunchImage() {

    # 由于无法使用LaunchScreen来适配单张启动图（无法清除iPhone缓存），因此使用了LaunchImage来设置启动图
    # LaunchImage需要的启动图需要对应尺寸，目前需要
    # 1125x2436(5.8英寸)  目前机型: iPhoneX
    # 1242x2208(5.5英寸)  目前机型: 6Plus，6sPlus，7Plus
    # 750x1334(4.7英寸)   目前机型: 6，6s，7
    # 640x1136(4英寸)     目前机型: 5，5s，SE
    # 640x960(3.5英寸)    目前机型: 4，4s
    LaunchImageArray=("1125x2436" "1242x2208" "750x1334" "640x1136" "640x960")
    LaunchImagePath="$Tmp_resource_path/LaunchImage"


    #========================= 生成LaunchImage =========================
    # 遍历查看对应尺寸Image
    LaunchImageIsBool="true"
    for i in "${!LaunchImageArray[@]}"; do
        if [ ! -f "${LaunchImagePath}${LaunchImageArray[$i]}.png" ]; then

            logit "【LaunchImage】缺少${LaunchImageArray[$i]}分辨率LaunchImage"
            LaunchImageIsBool="false"
        fi
    done

    if [ "$LaunchImageIsBool" = "false" ];then
        errorExit "LaunchImage图片不全，请补全对应尺寸资源文件。"   
    fi
    for i in "${!LaunchImageArray[@]}"; do
        # 替换LunchImage   cp -rf "${APP_LaunchImage_PATH}" "${BUILD_PROJECT}/${PROJECT_FILE_NAME}/Assets.xcassets/LaunchImage.imageset/LaunchImage.png"
        cp -rf "${LaunchImagePath}${LaunchImageArray[$i]}.png" "${project_build_path}/${project_name}/Assets.xcassets/LaunchImage.launchimage/LaunchImage${LaunchImageArray[$i]}.png"
        if [ $? -eq 0 ];then
            logit "【LaunchImage】拷贝${LaunchImageArray[$i]}.png 成功"
        else
            errorExit "拷贝${LaunchImageArray[$i]}.png 失败" 
        fi
    done
}

## 初始化用户配置
function initUserConfigFile() {
    
    #脚本全局参数配置文件user_config.plist(脚本参数优先于全局配置参数)
   
    # 项目名称
    project_name=`printPathPlist "project_name"`
    # 项目源码文件路径
    project_source_path=`printPathPlist "project_source_path"`
    # keychain解锁密码，即开机密码
    UNLOCK_KEYCHAIN_PWD=`printPathPlist "unlock_keychain_pwd"`
    # 授权文件目录，默认在~/Library/MobileDevice/Provisioning Profiles
    PROVISION_DIR=`printPathPlist "provision_dir"`
    if [[ "$PROVISION_DIR" ]]; then
        PROVISION_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
    fi
    # 构建模式：Debug/Release 
    # Simulation/AppStore
    CONFIGRATION_TYPE=`printPathPlist "configration_type"`

    # 指定分发渠道，development 内部分发，app-store商店分发，enterprise企业分发， ad-hoc 企业内部分发"
    CHANNEL=`printPathPlist "channel"`


    logit "【用户配置】项目名称: ${project_name}"
    logit "【用户配置】源码文件路径: ${project_source_path}"
    logit "【用户配置】预打包项目路径: ${project_build_path}"
    logit "【用户配置】keychain解锁密码: ${UNLOCK_KEYCHAIN_PWD}"
    logit "【用户配置】授权文件目录: ${PROVISION_DIR}"
    logit "【用户配置】构建模式: ${CONFIGRATION_TYPE}"
    logit "【用户配置】分发渠道: ${CHANNEL}"
    

}
## 初始化项目里配置
function initProjectConfig() {

    #**************************Resource/APP.plist ***************************
    APP_BundleId=`printResource_Config "BundleIdentifier"`
    APP_Name=`printResource_Config "Name"`
    #APP_Version=`printResource_Config "Version"`
    #APP_Build=`printResource_Config "Build"`

    #工程原BundleId
    project_CFBundleIdentifier=`printProject_Info "CFBundleIdentifier"`

    logit "【项目配置】APP名称: $APP_Name"
    logit "【项目配置】新BundleId: $APP_BundleId"
    logit "【项目配置】原BundleId: ${project_CFBundleIdentifier}"

}

## 更改项目infoPist
function changeProjectInfoPlist() {

    #========================= 更改info.plist文件 =========================
    
    setProject_Info "CFBundleIdentifier" "$APP_BundleId"
    setProject_Info "CFBundleDisplayName" "$APP_Name"
#    setProject_Info "CFBundleShortVersionString" "$APP_Version"
#    setProject_Info "CFBundleVersion" "$APP_Build"
    logit "【配置信息】更改后BundleId: `printProject_Info "CFBundleIdentifier"`"


    # project.pbxproj文件路径
    local pbxprojPath="${project_build_path}/${project_name}.xcodeproj/project.pbxproj"
    if [ ! -f "${pbxprojPath}" ]; then
        errorExit  "project.pbxproj文件不存在${pbxprojPath}"
    fi
    sed -i '' s/$project_CFBundleIdentifier/$APP_BundleId/g $pbxprojPath
    if [ $? -eq 0 ];then
        logit "【配置信息】修改project.pbxproj文件BundleId成功"
    else
        errorExit "修改project.pbxproj文件BundleId失败"
    fi
    
    

    #在Info中需要更改URLScheme (支付宝、微信URLScheme的设置)
    wechat_URLScheme=`printResource_Config "weChat_AppID"`

    UrlSchemeNameArray=("alipay" "wechat")
    # 下标对应UrlSchemeNameArray中
    UrlSchemesArray=($APP_BundleId $wechat_URLScheme) 
    # 遍历（带数组下标）
    for i in "${!UrlSchemeNameArray[@]}"; do
        #读取CFBundleURLTypes数组下第i个CFBundleURLName的值
        BundleUrlName=`printProject_Info "CFBundleURLTypes:$i:CFBundleURLName"`
        if [ $(contains "${UrlSchemeNameArray[@]}" ${BundleUrlName}) == "y" ]; then
            setProject_Info "CFBundleURLTypes:'${i}':CFBundleURLSchemes:0" "${UrlSchemesArray[$i]}"
            logit "【URLScheme配置】$BundleUrlName: ${UrlSchemesArray[$i]}"
        else
            logit "【URLScheme配置】${UrlSchemeNameArray[$i]}不存在!"
        fi
    done

}

## 更改项目配置文件
function changeProjectProfile() {
    
    #************************** 读取脚本配置文件Config.plist ***************************
    # CONFIG_project_id=`printResource_Config "project_id"`
    # CONFIG_merchant_id=`printResource_Config "merchant_id"`
    # CONFIG_system_color=`printResource_Config "system_color"`
    # CONFIG_baidu_MapKey=`printResource_Config "baidu_MapKey"`
    # CONFIG_weChat_AppID=`printResource_Config "weChat_AppID"`
    # CONFIG_weChat_AppSecret=`printResource_Config "weChat_AppSecret"`
    # CONFIG_uMeng_AppKey=`printResource_Config "uMeng_AppKey"`
    # CONFIG_bugly_AppId=`printResource_Config "bugly_AppId"`
    # CONFIG_bugly_AppKey=`printResource_Config "bugly_AppKey"`
    # CONFIG_jPush_AppKey=`printResource_Config "jPush_AppKey"`

    # CONFIG_home_page_num=`printResource_Config "home_page_num"`
    # CONFIG_mine_page_num=`printResource_Config "mine_page_num"`
    # CONFIG_is_allied_school=`printResource_Config "is_allied_school"`
    # CONFIG_login_type=`printResource_Config "login_type"`
    # CONFIG_is_always_show_guidepage=`printResource_Config "is_always_show_guidepage"`
    # CONFIG_guide_page_num=`printResource_Config "guide_page_num"`

    
    # logit "【项目配置】-------------------项目配置---------------------"
    # logit "【项目配置】project_id：               $CONFIG_project_id"
    # logit "【项目配置】merchant_id：              $CONFIG_merchant_id"
    # logit "【项目配置】system_color：             $CONFIG_system_color"
    # logit "【项目配置】baidu_MapKey：             $CONFIG_baidu_MapKey"
    # logit "【项目配置】uMeng_AppKey：             $CONFIG_uMeng_AppKey"
    # logit "【项目配置】bugly_AppId：              $CONFIG_bugly_AppId"
    # logit "【项目配置】bugly_AppKey：             $CONFIG_bugly_AppKey"
    # logit "【项目配置】jPush_AppKey：             $CONFIG_jPush_AppKey"
    # logit "【项目配置】weChat_AppID：             $CONFIG_weChat_AppID"
    # logit "【项目配置】weChat_AppSecret：         $CONFIG_weChat_AppSecret"

    # logit "【项目配置】home_page_num：            $CONFIG_home_page_num"
    # logit "【项目配置】mine_page_num：            $CONFIG_mine_page_num"
    # logit "【项目配置】is_allied_school：         $CONFIG_is_allied_school"
    # logit "【项目配置】login_type：               $CONFIG_login_type"
    # logit "【项目配置】is_always_show_guidepage： $CONFIG_is_always_show_guidepage"
    # logit "【项目配置】guide_page_num：           $CONFIG_guide_page_num"
    
    
    logit "【项目配置】更改项目中Config.plist文件..."
    
    # 脚本资源里Config.plist文件路径
    resource_config_plist="${Tmp_resource_path}/Config.plist"
    # 项目里Config.plist文件路径
    project_config_plist="${project_build_path}/${project_name}/Configs/Config.plist"
    
    if [ ! -f "${resource_config_plist}" ]; then
        errorExit "Resource中缺少Config.plist 文件"
    fi
    # cp -rf "${resource_config_plist}" "${project_config_plist}"
    

    for i in "${!ConfigPlistKeyArray[@]}"; do
        local dictKey=${ConfigPlistKeyArray[$i]}
        local dictValue=`printResource_Config "$dictKey"`
        # 替换对应值
        setProject_Config "$dictKey" "$dictValue"
        if [ $? -eq 0 ];then
            logit "【项目配置】$dictKey: $dictValue"
        else
            warning "替换Config.plist文件$dictKey失败"
        fi
    done


}

## 服务器调用脚本接口
## 根据项目需求从json文件获取资源配置信息
function configResourceFile() {

    # 临时存放资源文件目录
    Tmp_resource_path="${Package_Dir}/Resource/"
    mkdir -p $Tmp_resource_path
    # 拷贝配置文件模板config_tpl.plist到资源文件目录
    cp -rp "${Shell_File_Path}/config_tpl.plist" $Tmp_resource_path
    # 所需的json配置文件路径
    json_file_path=$1
    # 测试
    json_file_path="${Shell_File_Path}/test.json"

    resource_json_file="$Tmp_resource_path/config.json"
    logit "【资源配置】$resource_json_file" 
    # 复制打包参数json文件到打包脚本目录
    cp -rp $json_file_path $resource_json_file
    # 打印json
    jq . $resource_json_file

    # https://blog.csdn.net/offbye/article/details/38379195
    # mac下安装jq，使用brew install jq
    # 解析json 打包参数
    
    #************************** 工程配置信息 ***************************
 
    APP_Name=`cat $resource_json_file | jq -r '.app_name'`
    APP_BundleId=`cat $resource_json_file | jq -r '.APPLICATION_ID'`
    APP_Version=`cat $resource_json_file | jq -r '.VERSION_NAME'`
    APP_Build=`cat $resource_json_file | jq -r '.VERSION_CODE'`

    #************************** 业务配置信息 ***************************

    CONFIG_project_id=`cat $resource_json_file | jq -r '.PROJECTID'`
    CONFIG_merchant_id=`cat $resource_json_file | jq -r '.MERCHANT_ID'`
    CONFIG_system_color=`cat $resource_json_file | jq -r '.color_theme'`
    CONFIG_baidu_MapKey=`cat $resource_json_file | jq -r '.com_baidu_lbsapi_API_KEY'`
    CONFIG_uMeng_AppKey=`cat $resource_json_file | jq -r '.UMENGKEY'`
    CONFIG_bugly_AppId=`cat $resource_json_file | jq -r '.BUGLY_APPID'`
    CONFIG_bugly_AppKey=`cat $resource_json_file | jq -r '.'BUGLY_APPKEY`
    CONFIG_jPush_AppKey=`cat $resource_json_file | jq -r '.JPUSHKEY'`
    CONFIG_home_page_num=`cat $resource_json_file | jq -r '.TempletStatus'`
    CONFIG_mine_page_num=`cat $resource_json_file | jq -r '.PersonalCenterStatus'`
    CONFIG_is_allied_school=`cat $resource_json_file | jq -r '.IsAlliedSchool'`
    CONFIG_login_type=`cat $resource_json_file | jq -r '.LOGINFIRST'`
    CONFIG_is_always_show_guidepage=`cat $resource_json_file | jq -r '.GuideModel'`
    CONFIG_guide_page_num=`cat $resource_json_file | jq -r '.GuideCount'`
    # CONFIG_weChat_AppID=`printResource_Config "weChat_AppID"`
    # CONFIG_weChat_AppSecret=`printResource_Config "weChat_AppSecret"`
    #************************** 图片文件资源 ***************************
     
    apk_name=`cat $resource_json_file | jq -r '.apk_name'`
    icon=`cat $resource_json_file | jq -r '.icon'`
    start_img=`cat $resource_json_file | jq -r '.start_img'`

    GRADLE_SRC=`cat $resource_json_file | jq -r '.GRADLE_SRC'`
    uri_name=`cat $resource_json_file | jq -r '.Platform'`

    ## 下载图片
    # you-get -o ~/Desktop/PackageLog -O pic 'https://photo.16pic.com/00/03/11/16pic_311875_b.jpg'
    # icon
    you-get -o $Tmp_resource_path -O icon "$uri_name/$icon"


    # 脚本资源里Config.plist文件路径
    resource_config_plist="${Tmp_resource_path}/Config.plist"
    # 重命名
    mv "${Tmp_resource_path}config_tpl.plist" $resource_config_plist

    #修改配置文件config.plist
    logit "【资源配置】配置资源Config.plist文件中..."
    # key->value数组
    ConfigPlistValueArray=($APP_Name $APP_BundleId $APP_Version $APP_Build $CONFIG_project_id $CONFIG_merchant_id $CONFIG_system_color $CONFIG_baidu_MapKey $CONFIG_uMeng_AppKey $CONFIG_bugly_AppId $CONFIG_bugly_AppKey $CONFIG_jPush_AppKey $CONFIG_home_page_num $CONFIG_mine_page_num $CONFIG_is_allied_school $CONFIG_login_type $CONFIG_is_always_show_guidepage $CONFIG_guide_page_num $CONFIG_weChat_AppID $CONFIG_weChat_AppSecret)

    if [ ! -f "${resource_config_plist}" ]; then
        errorExit "Resource中缺少Config.plist 文件"
    fi

    for i in "${!ConfigPlistKeyArray[@]}"; do
        dictKey=${ConfigPlistKeyArray[$i]}
        dictValue=${ConfigPlistValueArray[$i]}
        # 替换对应值
        setResource_Config "$dictKey" "$dictValue"
        if [ $? -eq 0 ];then
            logit "【资源配置】$dictKey: $dictValue"
        else
            warning "配置资源Config.plist文件$dictKey失败"
        fi
    done
}











