/************************************************************************
 * @description A app for searching info about medications on a CMED database.
 * @file BuscaPMC.ahk
 * @author TheBrunoCA
 * @github https://www.github.com/TheBrunoCA
 * @date 2023/09/12
 * @version 0.01
 ***********************************************************************/
VERSION := 0.01
#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\libraries\Bruno-Functions\ImportAllList.ahk
#Include ..\libraries\Github-Updater.ahk\github-updater.ahk

; Exit codes
FailedToGetDatabase := 1 ;TODO: Erase the files.
Updating := 2

author := "TheBrunoCA"
repository := "BuscaPMC"
authorGitLink := "https://api.github.com/" author
repositoryGitLink := author "/" repository
github := Git(author, repository)

instalationDir := A_AppData "\" author "\" repository
configIniPath := instalationDir "\" repository "_config.ini"
inifile := Ini(configIniPath)

cmedUrl := "https://www.gov.br/anvisa/pt-br/assuntos/medicamentos/cmed/precos"
cmedHtml := GetPageContent(cmedUrl)
pmcDatabaseUrl := getPmcDatabaseUrl()
pmcDatabaseName := getPmcDatabaseName()

; Main user interface
MainGui := Gui("-MaximizeBox -Resize MinSize300x300", repository " por " author)
searchTxt := MainGui.AddText("vTxtSearch", "Selecione pelo o que deseja pesquisar")
searchEanRdBtn := MainGui.AddRadio("vRadioBtnSearchEan Checked Group", "Codigo de barras")
searchDescRdBtn := MainGui.AddRadio("vRadioBtnSearchDesc", "Descricao")
searchCompRdBtn := MainGui.AddRadio("vRadioBtnSearchComp", "Composicao")
searchTEdit := MainGui.AddEdit("vTEditSearch Uppercase w180")
searchSubmitBtn := MainGui.AddButton("vBtnSearch x192 y79 Default", "Buscar")
versionTxt := MainGui.AddText("x10 y110", "Versao: " VERSION)
searchSubmitBtn.OnEvent("Click", searchBtnClicked)



searchBtnClicked(args*){
    MsgBox(isInstalled())
}


if not isInstalled(){
    installApp()
}
checkDatabases()
checkVersion()



MainGui.Show()




; Functions
isInstalled(){
    return inifile["info", "isInstalled", false] == true
}

installApp(){
    NewDir(instalationDir)
    NewIni(configIniPath)
    inifile["info", "isInstalled"] := true
}

updateApp(){
    if not A_IsCompiled
        return

    github.DownloadLatest(A_Temp, A_ScriptName)
    batfile := BatWrite(instalationDir "\instalation_bat.bat")
    batfile.TimeOut(5)
    batfile.MoveFile(A_ScriptFullPath, A_Temp "\old_" A_ScriptName)
    batfile.TimeOut(5)
    batfile.MoveFile(A_Temp "\" A_ScriptName, A_ScriptFullPath)
    batfile.TimeOut(5)
    batfile.Start(A_ScriptFullPath)
    batfile.TimeOut(10)
    Run(batfile.path)
    ExitApp(Updating)
}

checkVersion(){
    if VERSION != inifile["info", "version", "0"]
        inifile["info", "version"] := VERSION

    if github.version == ""{
        return
    }
    if github.version > inifile["info", "version"]{
        answer := MsgBox("Nova versao do aplicativo disponivel, deseja atualizar?", , "0x4")
        if answer == "No"
            return
        updateApp()
    }
        
    
}

checkDatabases(){
    online := IsOnline()
    forcedUpdatePmc := false
    updatePmc := false

    if inifile["databases", "pmc_name"] == "Error"{
        deleteDatabases()
    }

    if online{
        if not FileExist(inifile["databases", "pmc_path"])
            forcedUpdatePmc := true
        else if inifile["databases", "pmc_name"] != pmcDatabaseName
            updatePmc := true

    }
    else{
        if not FileExist(inifile["databases", "pmc_path"]){
            MsgBox("Falha ao carregar e/ou baixar banco de dados, o aplicativo sera fechado.")
            ExitApp(FailedToGetDatabase)
        }
    }

    if forcedUpdatePmc{
        MsgBox("O aplicativo precisa atualizar o banco de dados, isso pode demorar.", , "T5")
        installPmcDatabase()
    }
    else if updatePmc{
        answer := MsgBox("Foi encontrada uma atualizacao do banco de dados, deseja atualizar?`nAltamente recomendado.", , "0x4")
        if answer == "Yes"
            installPmcDatabase()
    }



}

deleteDatabases(args*){
    try{
        FileDelete(instalationDir "\*.xls")
    }
}

corruptDatabases(args*){
    inifile["databases", "pmc_name"] := "Error"
    inifile["databases", "pmc_path"] := "Error"
    inifile["databases", "pmc_url"] := "Error"
    ExitApp(FailedToGetDatabase)
}

installPmcDatabase(){
    try{
        FileDelete(inifile["databases", "pmc_path"])
    }
    inifile["databases", "pmc_name", "test"] := pmcDatabaseName
    inifile["databases", "pmc_url"] := pmcDatabaseUrl
    inifile["databases", "pmc_path"] := instalationDir "\" pmcDatabaseName
    downloadFile(pmcDatabaseUrl, inifile["databases", "pmc_path"], , , corruptDatabases)
}

getPmcDatabaseName(){
    if pmcDatabaseUrl == ""
        return ""
    name := StrSplit(pmcDatabaseUrl, "arquivos/")[2]
    name := StrSplit(name, "/")[1]

    return name
}

getPmcDatabaseUrl(){
    if not InStr(cmedHtml, "Preço máximo"){
        MsgBox("Falha ao pegar banco de dados na CMED!")
        return ""
    }
    url := SubStr(cmedHtml, InStr(cmedHtml, "Preço máximo - pdf"))
    url := StrSplit(url, "Preço máximo - xls")[1]
    url := StrSplit(url, "href=")[2]
    url := StrReplace(url, "`n", "")
    url := StrReplace(url, "   ", "")
    url := StrSplit(url, "><")[1]
    url := StrReplace(url, '"', "")

    return url
}