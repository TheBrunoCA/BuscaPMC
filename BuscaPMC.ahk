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

author := "TheBrunoCA"
repository := "BuscaPMC"
authorGitLink := "https://api.github.com/" author
repositoryGitLink := author "/" repository
github := Git(author, repository)

instalationDir := A_AppData "/" author "/" repository
executablePath := instalationDir "/" repository ".exe"
configIniPath := instalationDir "/" repository "_config.ini"

cmedUrl := "https://www.gov.br/anvisa/pt-br/assuntos/medicamentos/cmed/precos"
pmcDatabaseUrl := ""
datasetPath := instalationDir "/pmc_teste.xls"
;productDataset := Dataset(datasetPath)

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
    if !inifile.hasValue("DATABASES", "pmc"){
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
}

getPMCDatabase(){
    
}