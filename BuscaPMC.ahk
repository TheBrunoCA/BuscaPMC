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
#Include DatasetClass.ahk

author := "TheBrunoCA"
repository := "BuscaPMC"
authorGitLink := "https://api.github.com/" author
repositoryGitLink := author "/" repository

instalationDir := A_AppData "/" author "/" repository
executablePath := instalationDir "/" repository ".exe"
configIniPath := instalationDir "/" repository "_config.ini"

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

if(!isInstalled()){
    installApp()
}



MainGui.Show()



; Functions
isInstalled(){
    return FileExist(executablePath) != ""
}

installApp(){
    NewDir(instalationDir)
    NewIni(configIniPath)
    
}