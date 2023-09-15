/************************************************************************
 * @description A app for searching info about medications on a CMED database.
 * @file BuscaPMC.ahk
 * @author TheBrunoCA
 * @github https://www.github.com/TheBrunoCA
 * @date 2023/09/12
 * @version 0.0.1
 ***********************************************************************/
VERSION := "0.0.1"
#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\libraries\Bruno-Functions\ImportAllList.ahk
#Include ..\libraries\Github-Updater.ahk\github-updater.ahk
#Include DatasetClass.ahk

; Exit codes
FailedToGetDatabase := 1 ;TODO: Erase the files.

author := "TheBrunoCA"
repository := "BuscaPMC"
authorGitLink := "https://api.github.com/" author
repositoryGitLink := author "/" repository
github := Git(author, repository)

instalationDir := A_AppData "/" author "/" repository
executablePath := instalationDir "/" repository ".exe"
configIniPath := instalationDir "/" repository "_config.ini"

cmedUrl := "https://www.gov.br/anvisa/pt-br/assuntos/medicamentos/cmed/precos"
cmedHtml := GetPageContent(cmedUrl)
pmcDatabaseUrl := getPmcDatabaseUrl()
pmcDatabaseName := getPmcDatabaseName()

MainGui := Gui("-MaximizeBox -Resize MinSize300x300", repository " por " author)
searchTxt := MainGui.AddText("vTxtSearch", "Selecione pelo o que deseja pesquisar")
searchEanRdBtn := MainGui.AddRadio("vRadioBtnSearchEan Checked Group", "Codigo de barras")
searchDescRdBtn := MainGui.AddRadio("vRadioBtnSearchDesc", "Descricao")
searchCompRdBtn := MainGui.AddRadio("vRadioBtnSearchComp", "Composicao")
searchTEdit := MainGui.AddEdit("vTEditSearch Uppercase")
searchSubmitBtn := MainGui.AddButton("vBtnSearch x135 y81", "Buscar")
searchSubmitBtn.OnEvent("Click", searchBtnClicked)

searchBtnClicked(args*){
    MsgBox(isInstalled())
}

if !isInstalled(){
    installApp()
}

checkDatabases()



MainGui.Show()



; Functions
isInstalled(){
    return FileExist(executablePath) != ""
}

installApp(){
    NewDir(instalationDir)
    NewIni(configIniPath)
    
}

checkDatabases(){
    inifile := Ini(configIniPath)
    if IsOnline() == false{
        if inifile["databases", "pmc_name"] == ""{
            MsgBox("Falha ao carregar e/ou baixar o banco de dados, o aplicativo sera fechado.")
            ExitApp(FailedToGetDatabase)
        }
    }

    if inifile["databases", "pmc_name", "wow"] != pmcDatabaseName{
        if FileExist(inifile["databases", "pmc_path"]) == ""
            MsgBox("O aplicativo irá baixar os bancos de dados, isso pode demorar. Ele ira abrir sozinho ao terminar.")

        else{
            answer := MsgBox("Atualizacao disponivel para os bancos de dados, deseja atualizar?`nAltamente recomendado.", , "0x4")
            if answer == "No"
                return
            MsgBox("O aplicativo irá baixar os bancos de dados, isso pode demorar. Ele ira abrir sozinho ao terminar.")
        }

        try{
            FileDelete(inifile["databases", "pmc_path"])
        }
        inifile["databases", "pmc_name", "test"] := pmcDatabaseName
        inifile["databases", "pmc_url"] := pmcDatabaseUrl
        inifile["databases", "pmc_path"] := instalationDir "\" pmcDatabaseName
        Download(pmcDatabaseUrl, inifile["databases", "pmc_path"])
    }
}

getPmcDatabaseName(){
    if pmcDatabaseUrl == ""
        return ""
    name := StrSplit(pmcDatabaseUrl, "arquivos/")[2]
    name := StrSplit(name, "/")[1]

    return name
}

getPmcDatabaseUrl(){
    if !InStr(cmedHtml, "Preço máximo"){
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

getPMCDatabaseaaa(){
    html := GetPageContent(cmedUrl)
        if !InStr(html, "Preço máximo - xls"){
            MsgBox("Falha ao pegar banco de dados na CMED.")
        }
        position := InStr(html, "Preço máximo - pdf")
        html := SubStr(html, position)
        html := StrSplit(html, "Preço máximo - xls")
        downloadLink := SubStr(html[1], InStr(html[1], "href"))
        downloadLink := StrSplit(downloadLink, "=")
        downloadLink := StrSplit(downloadLink[2], ">")
        downloadLink := downloadLink[1]
        downloadLink := StrReplace(downloadLink, '"', "")
        databaseName := StrSplit(downloadLink, "/")
        databaseName := GetFromSimpleArray(databaseName, "arquivos")
        MsgBox(downloadLink)
        MsgBox(databaseName)
}