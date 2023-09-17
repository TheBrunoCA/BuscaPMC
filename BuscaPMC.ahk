/************************************************************************
 * @description A app for searching info about medications on a CMED database.
 * @file BuscaPMC.ahk
 * @author TheBrunoCA
 * @github https://www.github.com/TheBrunoCA
 * @date 2023/09/12
 * @version 0.11
 ***********************************************************************/
VERSION := "0.11"
#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\libraries\Bruno-Functions\ImportAllList.ahk
#Include ..\libraries\Github-Updater.ahk\github-updater.ahk

; Exit codes
FailedToGetDatabase := 1 ;TODO: Erase the files.
Updating := 2

OnExit(exitFunc)


progressCounter := 0
maxProgress := 8

author := "TheBrunoCA"
repository := "BuscaPMC"


loading := loadingScreen("Carregando...", repository " por " author, &progressCounter, maxProgress)
loading.start()


authorGitLink := "https://api.github.com/" author
repositoryGitLink := author "/" repository
github := Git(author, repository)

progressCounter += 1

instalationDir := A_AppData "\" author "\" repository
configIniPath := instalationDir "\" repository "_config.ini"
inifile := Ini(configIniPath)

progressCounter += 1

cmedUrl := "https://www.gov.br/anvisa/pt-br/assuntos/medicamentos/cmed/precos"
cmedHtml := GetPageContent(cmedUrl)
pmcDatabaseUrl := getPmcDatabaseUrl()
pmcDatabaseName := getPmcDatabaseName()

progressCounter += 1

; Main user interface
MainGui := Gui("-MaximizeBox -Resize MinSize300x300", repository " por " author)
searchTxt := MainGui.AddText("vTxtSearch", "Selecione pelo o que deseja pesquisar")
searchEanRdBtn := MainGui.AddRadio("vRadioBtnSearchEan Checked Group", "Codigo de barras")
;searchDescRdBtn := MainGui.AddRadio("vRadioBtnSearchDesc", "Descricao")
;searchCompRdBtn := MainGui.AddRadio("vRadioBtnSearchComp", "Composicao")
searchTEdit := MainGui.AddEdit("vTEditSearch Uppercase w180")
searchSubmitBtn := MainGui.AddButton("vBtnSearch x192 y42 Default", "Buscar")
versionTxt := MainGui.AddText("x10 y110", "Versao: " VERSION)
searchSubmitBtn.OnEvent("Click", searchBtnClicked)

searchBtnClicked(args*){
    if searchEanRdBtn.Value == true{
        ean := searchTEdit.Value
        try{
            temp := ean * 2
        } catch Error as e{
            if InStr(e.Message, "String"){
                MsgBox("O campo deve conter apenas numeros.")
                searchTEdit.Value := ""
                return
            }
        }
        item := getItemFromPmcDatabaseByEan(ean)
        showItem(item)
        searchTEdit.Value := ""
    }
}

progressCounter += 1

if not isInstalled(){
    installApp()
}

checkDatabases()

progressCounter += 1

try{
    if WinExist(inifile["databases", "pmc_name"])
        WinClose(inifile["databases", "pmc_name"])
}

pmcDatabase := ExcelClass(inifile["databases", "pmc_path"])

progressCounter += 1

checkPmcParameters()

progressCounter += 1

checkVersion()

progressCounter += 1

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
        answer := MsgBox("Nova versao do aplicativo disponivel, deseja atualizar?", , "0x1004 T30")
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
            MsgBox("Falha ao carregar e/ou baixar banco de dados, o aplicativo sera fechado.", , "0x1000 T5")
            ExitApp(FailedToGetDatabase)
        }
    }

    if forcedUpdatePmc{
        MsgBox("O aplicativo precisa atualizar o banco de dados, isso pode demorar.", , "0x1000 T10")
        installPmcDatabase()
    }
    else if updatePmc{
        answer := MsgBox("Foi encontrada uma atualizacao do banco de dados, deseja atualizar?`nAltamente recomendado.", , "0x1004")
        if answer == "Yes"
            installPmcDatabase()
    }
}

checkPmcParameters(){

    progress := 0
    mProgress := 46

    load := loadingScreen("Carregando parametros...", repository " por " author, &progress, mProgress)
    load.start()

    if inifile["positions_pmc", "reset"] == true
        inifile.delete("positions_pmc")
    progress += 1
    if inifile["positions_pmc", "composition"] == ""
        inifile["positions_pmc", "composition"] := pmcDatabase.getValueColumn("SUBSTÂNCIA", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "lab_cnpj"] == ""
        inifile["positions_pmc", "lab_cnpj"] := pmcDatabase.getValueColumn("CNPJ", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "lab_name"] == ""
        inifile["positions_pmc", "lab_name"] := pmcDatabase.getValueColumn("LABORATÓRIO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "ggrem"] == ""
        inifile["positions_pmc", "ggrem"] := pmcDatabase.getValueColumn("CÓDIGO GGREM", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "ms"] == ""
        inifile["positions_pmc", "ms"] := pmcDatabase.getValueColumn("REGISTRO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "ean"] == ""
        inifile["positions_pmc", "ean"] := pmcDatabase.getValueColumn("EAN 1", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "ean2"] == ""
        inifile["positions_pmc", "ean2"] := pmcDatabase.getValueColumn("EAN 2", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "name"] == ""
        inifile["positions_pmc", "name"] := pmcDatabase.getValueColumn("PRODUTO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "presentation"] == ""
        inifile["positions_pmc", "presentation"] := pmcDatabase.getValueColumn("APRESENTAÇÃO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "class"] == ""
        inifile["positions_pmc", "class"] := pmcDatabase.getValueColumn("CLASSE TERAPÊUTICA", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "type"] == ""
        inifile["positions_pmc", "type"] := pmcDatabase.getValueColumn("TIPO DE PRODUTO (STATUS DO PRODUTO)", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "price_control"] == ""
        inifile["positions_pmc", "price_control"] := pmcDatabase.getValueColumn("REGIME DE PREÇO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_untributed"] == ""
        inifile["positions_pmc", "pf_untributed"] := pmcDatabase.getValueColumn("PF Sem Impostos", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_0"] == ""
        inifile["positions_pmc", "pf_0"] := pmcDatabase.getValueColumn("PF 0%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_12"] == ""
        inifile["positions_pmc", "pf_12"] := pmcDatabase.getValueColumn("PF 12%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_17"] == ""
        inifile["positions_pmc", "pf_17"] := pmcDatabase.getValueColumn("PF 17%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_17_alc"] == ""
        inifile["positions_pmc", "pf_17_alc"] := pmcDatabase.getValueColumn("PF 17% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_17_5"] == ""
        inifile["positions_pmc", "pf_17_5"] := pmcDatabase.getValueColumn("PF 17,5%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_17_5_alc"] == ""
        inifile["positions_pmc", "pf_17_5_alc"] := pmcDatabase.getValueColumn("PF 17,5% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_18"] == ""
        inifile["positions_pmc", "pf_18"] := pmcDatabase.getValueColumn("PF 18%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_18_alc"] == ""
        inifile["positions_pmc", "pf_18_alc"] := pmcDatabase.getValueColumn("PF 18% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_19"] == ""
        inifile["positions_pmc", "pf_19"] := pmcDatabase.getValueColumn("PF 19%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_20"] == ""
        inifile["positions_pmc", "pf_20"] := pmcDatabase.getValueColumn("PF 20%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_21"] == ""
        inifile["positions_pmc", "pf_21"] := pmcDatabase.getValueColumn("PF 21%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_22"] == ""
        inifile["positions_pmc", "pf_22"] := pmcDatabase.getValueColumn("PF 22%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_0"] == ""
        inifile["positions_pmc", "pmc_0"] := pmcDatabase.getValueColumn("PMC 0%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_12"] == ""
        inifile["positions_pmc", "pmc_12"] := pmcDatabase.getValueColumn("PMC 12%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_17"] == ""
        inifile["positions_pmc", "pmc_17"] := pmcDatabase.getValueColumn("PMC 17%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_17_alc"] == ""
        inifile["positions_pmc", "pmc_17_alc"] := pmcDatabase.getValueColumn("PMC 17% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_17_5"] == ""
        inifile["positions_pmc", "pmc_17_5"] := pmcDatabase.getValueColumn("PMC 17,5%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_17_5_alc"] == ""
        inifile["positions_pmc", "pmc_17_5_alc"] := pmcDatabase.getValueColumn("PMC 17,5% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_18"] == ""
        inifile["positions_pmc", "pmc_18"] := pmcDatabase.getValueColumn("PMC 18%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_18_alc"] == ""
        inifile["positions_pmc", "pmc_18_alc"] := pmcDatabase.getValueColumn("PMC 18% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_19"] == ""
        inifile["positions_pmc", "pmc_19"] := pmcDatabase.getValueColumn("PMC 19%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_20"] == ""
        inifile["positions_pmc", "pmc_20"] := pmcDatabase.getValueColumn("PMC 20%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_21"] == ""
        inifile["positions_pmc", "pmc_21"] := pmcDatabase.getValueColumn("PMC 21%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_22"] == ""
        inifile["positions_pmc", "pmc_22"] := pmcDatabase.getValueColumn("PMC 22%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "hospital_only"] == ""
        inifile["positions_pmc", "hospital_only"] := pmcDatabase.getValueColumn("RESTRIÇÃO HOSPITALAR", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "cap"] == ""
        inifile["positions_pmc", "cap"] := pmcDatabase.getValueColumn("CAP", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "confaz_87"] == ""
        inifile["positions_pmc", "confaz_87"] := pmcDatabase.getValueColumn("CONFAZ 87", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "icms_0"] == ""
        inifile["positions_pmc", "icms_0"] := pmcDatabase.getValueColumn("ICMS 0%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "recursal"] == ""
        inifile["positions_pmc", "recursal"] := pmcDatabase.getValueColumn("ANÁLISE RECURSAL", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pis_cofins"] == ""
        inifile["positions_pmc", "pis_cofins"] := pmcDatabase.getValueColumn("LISTA DE CONCESSÃO DE CRÉDITO TRIBUTÁRIO (PIS/COFINS)", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "commercialized"] == ""
        inifile["positions_pmc", "commercialized"] := pmcDatabase.getValueColumn("COMERCIALIZAÇÃO 2022", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "stripe"] == ""
        inifile["positions_pmc", "stripe"] := pmcDatabase.getValueColumn("TARJA", "40:" pmcDatabase.rowCount)
    progress += 1

    load.stop()
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
    progress := 0
    mProgress := 6

    load := loadingScreen("Instalando banco de dados PMC...", repository " por " author, &progress, mProgress)
    load.start()

    try{
        FileDelete(inifile["databases", "pmc_path"])
    }
    progress += 1
    inifile["databases", "pmc_name", "test"] := pmcDatabaseName
    progress += 1
    inifile["databases", "pmc_url"] := pmcDatabaseUrl
    progress += 1
    inifile["databases", "pmc_path"] := instalationDir "\" pmcDatabaseName
    progress += 1
    inifile["positions_pmc", "reset"] := true
    progress += 1
    downloadFile(pmcDatabaseUrl, inifile["databases", "pmc_path"], , , corruptDatabases)
    progress += 1
    
    load.stop()
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

getItemFromPmcDatabaseByEan(ean){
    progress := 0
    mProgress := 45

    load := loadingScreen("Buscando dados do item...", repository " por " author, &progress, mProgress)
    load.start()
    
    eanColumn := inifile["positions_pmc", "ean"]
    eanColumn .= ":" eanColumn

    item := ItemClass()
    item.row_on_database := pmcDatabase.getValueRow(ean, eanColumn)
    if not item.row_on_database{
        MsgBox("Nao foi encontrado nenhum produto com esse codigo de barras", "Erro", "0x1000 T10")
        return
    }
    mProgress += 1
    item.composition := pmcDatabase.getValue(inifile["positions_pmc", "composition"] item.row_on_database)
    mProgress += 1
    item.lab_cnpj := pmcDatabase.getValue(inifile["positions_pmc", "lab_cnpj"] item.row_on_database)
    mProgress += 1
    item.lab_name := pmcDatabase.getValue(inifile["positions_pmc", "lab_name"] item.row_on_database)
    mProgress += 1
    item.ggrem := pmcDatabase.getValue(inifile["positions_pmc", "ggrem"] item.row_on_database)
    mProgress += 1
    item.ms := pmcDatabase.getValue(inifile["positions_pmc", "ms"] item.row_on_database)
    mProgress += 1
    item.ean := pmcDatabase.getValue(inifile["positions_pmc", "ean"] item.row_on_database)
    mProgress += 1
    item.ean2 := pmcDatabase.getValue(inifile["positions_pmc", "ean2"] item.row_on_database)
    mProgress += 1
    item.name := pmcDatabase.getValue(inifile["positions_pmc", "name"] item.row_on_database)
    mProgress += 1
    item.presentation := pmcDatabase.getValue(inifile["positions_pmc", "presentation"] item.row_on_database)
    mProgress += 1
    item.class := pmcDatabase.getValue(inifile["positions_pmc", "class"] item.row_on_database)
    mProgress += 1
    item.type := pmcDatabase.getValue(inifile["positions_pmc", "type"] item.row_on_database)
    mProgress += 1
    item.price_control := pmcDatabase.getValue(inifile["positions_pmc", "price_control"] item.row_on_database)
    mProgress += 1
    item.pf_untributed := pmcDatabase.getValue(inifile["positions_pmc", "pf_untributed"] item.row_on_database)
    mProgress += 1
    item.pf_0 := pmcDatabase.getValue(inifile["positions_pmc", "pf_0"] item.row_on_database)
    mProgress += 1
    item.pf_12 := pmcDatabase.getValue(inifile["positions_pmc", "pf_12"] item.row_on_database)
    mProgress += 1
    item.pf_17 := pmcDatabase.getValue(inifile["positions_pmc", "pf_17"] item.row_on_database)
    mProgress += 1
    item.pf_17_alc := pmcDatabase.getValue(inifile["positions_pmc", "pf_17_alc"] item.row_on_database)
    mProgress += 1
    item.pf_17_5 := pmcDatabase.getValue(inifile["positions_pmc", "pf_17_5"] item.row_on_database)
    mProgress += 1
    item.pf_17_5_alc := pmcDatabase.getValue(inifile["positions_pmc", "pf_17_5_alc"] item.row_on_database)
    mProgress += 1
    item.pf_18 := pmcDatabase.getValue(inifile["positions_pmc", "pf_18"] item.row_on_database)
    mProgress += 1
    item.pf_18_alc := pmcDatabase.getValue(inifile["positions_pmc", "pf_18_alc"] item.row_on_database)
    mProgress += 1
    item.pf_19 := pmcDatabase.getValue(inifile["positions_pmc", "pf_19"] item.row_on_database)
    mProgress += 1
    item.pf_20 := pmcDatabase.getValue(inifile["positions_pmc", "pf_20"] item.row_on_database)
    mProgress += 1
    item.pf_21 := pmcDatabase.getValue(inifile["positions_pmc", "pf_21"] item.row_on_database)
    mProgress += 1
    item.pf_22 := pmcDatabase.getValue(inifile["positions_pmc", "pf_22"] item.row_on_database)
    mProgress += 1
    item.pmc_0 := pmcDatabase.getValue(inifile["positions_pmc", "pmc_0"] item.row_on_database)
    mProgress += 1
    item.pmc_12 := pmcDatabase.getValue(inifile["positions_pmc", "pmc_12"] item.row_on_database)
    mProgress += 1
    item.pmc_17 := pmcDatabase.getValue(inifile["positions_pmc", "pmc_17"] item.row_on_database)
    mProgress += 1
    item.pmc_17_alc := pmcDatabase.getValue(inifile["positions_pmc", "pmc_17_alc"] item.row_on_database)
    mProgress += 1
    item.pmc_17_5 := pmcDatabase.getValue(inifile["positions_pmc", "pmc_17_5"] item.row_on_database)
    mProgress += 1
    item.pmc_17_5_alc := pmcDatabase.getValue(inifile["positions_pmc", "pmc_17_5_alc"] item.row_on_database)
    mProgress += 1
    item.pmc_18 := pmcDatabase.getValue(inifile["positions_pmc", "pmc_18"] item.row_on_database)
    mProgress += 1
    item.pmc_19 := pmcDatabase.getValue(inifile["positions_pmc", "pmc_19"] item.row_on_database)
    mProgress += 1
    item.pmc_20 := pmcDatabase.getValue(inifile["positions_pmc", "pmc_20"] item.row_on_database)
    mProgress += 1
    item.pmc_21 := pmcDatabase.getValue(inifile["positions_pmc", "pmc_21"] item.row_on_database)
    mProgress += 1
    item.pmc_22 := pmcDatabase.getValue(inifile["positions_pmc", "pmc_22"] item.row_on_database)
    mProgress += 1
    item.hospital_only := pmcDatabase.getValue(inifile["positions_pmc", "hospital_only"] item.row_on_database)
    mProgress += 1
    item.cap := pmcDatabase.getValue(inifile["positions_pmc", "cap"] item.row_on_database)
    mProgress += 1
    item.confaz_87 := pmcDatabase.getValue(inifile["positions_pmc", "confaz_87"] item.row_on_database)
    mProgress += 1
    item.icms_0 := pmcDatabase.getValue(inifile["positions_pmc", "icms_0"] item.row_on_database)
    mProgress += 1
    item.recursal := pmcDatabase.getValue(inifile["positions_pmc", "recursal"] item.row_on_database)
    mProgress += 1
    item.pis_cofins := pmcDatabase.getValue(inifile["positions_pmc", "pis_cofins"] item.row_on_database)
    mProgress += 1
    item.commercialized := pmcDatabase.getValue(inifile["positions_pmc", "commercialized"] item.row_on_database)
    mProgress += 1
    item.stripe := pmcDatabase.getValue(inifile["positions_pmc", "stripe"] item.row_on_database)
    mProgress += 1

    load.stop()
    return item
}

showItem(item){
    gItem           := Gui("+AlwaysOnTop -MaximizeBox", item.name)
    gtxtName        := gItem.AddText("xm5", "Nome:`n" item.name)
    gtxtType        := gItem.AddText("xm5", "Tipo:`n" item.type)
    gtxtEan         := gItem.AddText("xm5", "Codigo de barras:`n" item.ean)
    gtxtComp        := gItem.AddText("xm5", "Composicao:`n" item.composition)
    gtxtPres        := gItem.AddText("xm5", "Apresentacao:`n" item.presentation)
    gtxtLab         := gItem.AddText("xm5", "Laboratorio:`n" item.lab_name)
    gtxtMs          := gItem.AddText("xm5", "Registro MS:`n" item.ms)
    gtxtClass       := gItem.AddText("xm5", "Classe terapeutica:`n" item.class)
    gtxtStripe      := gItem.AddText("xm5", "Tarja:`n" item.stripe)
    gtxtPf          := gItem.AddText("xm5", "Preco fabrica:`n")
    gtxtPf.Text     .= gtxtType.Text == "Genérico" ? item.pf_12 : item.pf_18
    gtxtPmc         := gItem.AddText("xm5", "Preco Maximo Consumidor:`n")
    gtxtPmc.Text    .= gtxtType.Text == "Genérico" ? item.pmc_12 : item.pmc_18
    gtxtPisCofins   := gItem.AddText("xm5", "Lista PIS/COFINS:`n" item.pis_cofins)

    gItem.Show()
}

exitFunc(args*){
    try{
        pmcDatabase.close()
    }
    
}

class ItemClass{
    __New() {
        this.row_on_database := ""
        this.composition := ""
        this.lab_cnpj := ""
        this.lab_name := ""
        this.ggrem := ""
        this.ms := ""
        this.ean := ""
        this.ean2 := ""
        this.name := ""
        this.presentation := ""
        this.class := ""
        this.type := ""
        this.price_control := ""
        this.pf_untributed := ""
        this.pf_0 := ""
        this.pf_12 := ""
        this.pf_17 := ""
        this.pf_17_alc := ""
        this.pf_17_5 := ""
        this.pf_17_5_alc := ""
        this.pf_18 := ""
        this.pf_18_alc := ""
        this.pf_19 := ""
        this.pf_20 := ""
        this.pf_21 := ""
        this.pf_22 := ""
        this.pmc_0 := ""
        this.pmc_12 := ""
        this.pmc_17 := ""
        this.pmc_17_alc := ""
        this.pmc_17_5 := ""
        this.pmc_17_5_alc := ""
        this.pmc_18 := ""
        this.pmc_18_alc := ""
        this.pmc_19 := ""
        this.pmc_20 := ""
        this.pmc_21 := ""
        this.pmc_22 := ""
        this.hospital_only := ""
        this.cap := ""
        this.confaz_87 := ""
        this.icms_0 := ""
        this.recursal := ""
        this.pis_cofins := ""
        this.commercialized := ""
        this.stripe := ""
    }
}

loading.stop()