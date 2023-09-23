/************************************************************************
 * @description A app for searching info about medications on a CMED database.
 * @file BuscaPMC.ahk
 * @author TheBrunoCA
 * @github https://www.github.com/TheBrunoCA
 * @date 2023/09/12
 ***********************************************************************/
VERSION := "0.142"
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
instalationBatPath := instalationDir "\instalation_bat.bat"
inifile := Ini(configIniPath)
if inifile["info", "exe_path"] != A_ScriptFullPath and A_IsCompiled
    inifile["info", "exe_path"] := A_ScriptFullPath
wasUpdated := FileExist(instalationBatPath)
try{
    FileDelete(instalationBatPath)
}
if wasUpdated{
    MsgBox(github.update_message, "O aplicativo foi atualizado", "0x1000 T120")
}

progressCounter += 1

cmedUrl         := "https://www.gov.br/anvisa/pt-br/assuntos/medicamentos/cmed/precos"
cmedHtml        := GetPageContent(cmedUrl)
pmcDatabaseUrl  := getPmcDatabaseUrl()
pmcDatabaseName := getPmcDatabaseName()

progressCounter += 1

; Main user interface
MainGui         := Gui("-MaximizeBox -Resize MinSize300x300", repository " por " author)
searchTxt       := MainGui.AddText("vTxtSearch", "Digite o que deseja pesquisar.")
searchNameRdBtn := MainGui.AddRadio("Checked", "Nome")
searchCompRdBtn := MainGui.AddRadio("yp x+10", "Composicao")
searchTEdit     := MainGui.AddEdit("vTEditSearch Uppercase w180 yp+20 xm5")
searchTEdit     .Focus()
searchSubmitBtn := MainGui.AddButton("vBtnSearch x+5 yp Default", "Buscar")
maxItemTxt      := MainGui.AddText("y+10 xm5", "Resultados maximos: ")
maxItemTedit    := MainGui.AddEdit("yp-3 x+2 w30 Number", inifile["config", "max_items_on_list", 0])
maxItemTedit.OnEvent("Change", maxItemEditChange)
maxItemEditChange(obj, info){
    if obj.Value == emptyStr or not IsNumber(obj.Value)
        obj.Value := 0
    inifile["config", "max_items_on_list"] := obj.Value >= 0 ? obj.Value : 0
}
versionTxt      := MainGui.AddText("yp x+20", "Versao: " VERSION)
searchSubmitBtn .OnEvent("Click", searchBtnClicked)

searchBtnClicked(args*) {
    text := searchTEdit.Value
    if StrReplace(text, " ", "") == emptyStr
        return
    if InStr(text, "LAB:"){
        txt := StrSplit(text, "LAB:")
        if StrReplace(txt[1], " ", "") == emptyStr
            return
    }

    if IsNumber(text) {
        item := getItemFromEan(text)
        if not item {
            MsgBox("Nao foi encontrado nenhum item com esse codigo de barras", , "0x1000 T10")
            searchTEdit.Value := ""
            return
        }
        showItem(item)
        searchTEdit.Value := ""
        return
    } else {
        method := searchNameRdBtn.Value == true ? "Name" : "Comp"
        list := getListOfItemsByDesc(text, method)
        if not list.Count {
            MsgBox("Nao foi encontrado nenhum item com essa descricao", , "0x1000 T10")
            searchTEdit.Value := ""
            return
        }
        showListOfItems(list)
    }
}

progressCounter += 1

if not isInstalled() {
    installApp()
}

checkDatabases()

progressCounter += 1

try {
    if WinExist(inifile["databases", "pmc_name"])
        WinClose(inifile["databases", "pmc_name"])
}

try {
    pmcDatabase := ExcelClass(inifile["databases", "pmc_path"])
} catch {
    if ProcessExist("EXCEL.EXE") {
        answer := MsgBox("O Excel precisa estar fechado para o aplicativo funcionar, por favor feche-o.`n"
            "Se apertar OK, o Excel sera fechado automaticamente e o que nao tiver sido salvo sera perdido.`n"
            "Aperte CANCELAR para cancelar a abertura do aplicativo.", , "0x1")

        if answer == "OK" {
            try {
                WinClose("Excel")
                ProcessClose("EXCEL.EXE")
            }
        }
        else {
            ExitApp()
        }

        try {
            pmcDatabase := ExcelClass(inifile["databases", "pmc_path"])
        } catch {
            MsgBox("O banco de dados esta corrompido. O aplicativo ira tentar baixa-lo novamente.")
            deleteDatabases()
            corruptDatabases()
        }
    } else {
        MsgBox("O banco de dados esta corrompido. O aplicativo ira tentar baixa-lo novamente.")
        deleteDatabases()
        corruptDatabases()
    }
}


progressCounter += 1

checkPmcParameters()

progressCounter += 1

checkVersion()

progressCounter += 1

MainGui.Show()


; Functions
isInstalled() {
    return inifile["info", "isInstalled", false] == true
}

installApp() {
    NewDir(instalationDir)
    NewIni(configIniPath)
    inifile["info", "isInstalled"] := true
    inifile["config", "max_items_on_list"] := 50

}

updateApp() {
    if not A_IsCompiled
        return
    if github.online {
        github.DownloadLatest(A_Temp, A_ScriptName)
        batfile := BatWrite(instalationBatPath)
        batfile.MoveFile(A_ScriptFullPath, A_Temp "\old_" A_ScriptName)
        batfile.MoveFile(A_Temp "\" A_ScriptName, A_ScriptFullPath)
        batfile.Start(A_ScriptFullPath)
        Run(batfile.path, , "Hide")
        ExitApp(Updating)
    }
}

checkVersion() {
    if VERSION != inifile["info", "version", "0"]
        inifile["info", "version"] := VERSION

    if not github.online
        return

    if github.version == emptyStr {
        return
    }
    if github.version > inifile["info", "version"] {
        answer := MsgBox("Nova versao do aplicativo disponivel, deseja atualizar?", , "0x1004 T30")
        if answer == "No"
            return
        updateApp()
    }


}

checkDatabases() {
    online := IsOnline()
    forcedUpdatePmc := false
    updatePmc := false

    if inifile["databases", "pmc_name"] == "Error" {
        deleteDatabases()
    }

    if online {
        if not FileExist(inifile["databases", "pmc_path"])
            forcedUpdatePmc := true
        else if inifile["databases", "pmc_name"] != pmcDatabaseName
            updatePmc := true

    }
    else {
        if not FileExist(inifile["databases", "pmc_path"]) {
            MsgBox("Falha ao carregar e/ou baixar banco de dados, o aplicativo sera fechado.", , "0x1000 T5")
            ExitApp(FailedToGetDatabase)
        }
    }

    if forcedUpdatePmc {
        MsgBox("O aplicativo precisa atualizar o banco de dados, isso pode demorar.", , "0x1000 T10")
        installPmcDatabase()
    }
    else if updatePmc {
        answer := MsgBox("Foi encontrada uma atualizacao do banco de dados, deseja atualizar?`nAltamente recomendado.", , "0x1004")
        if answer == "Yes"
            installPmcDatabase()
    }
}

checkPmcParameters() {

    progress := 0
    mProgress := 46
    load := loadingScreen("Carregando parametros...", repository " por " author, &progress, mProgress)
    load.start()

    if inifile["positions_pmc", "reset"] == true
        inifile.delete("positions_pmc")
    progress += 1
    if inifile["positions_pmc", "composition"] == emptyStr
        inifile["positions_pmc", "composition"]     := pmcDatabase.getValueColumn("SUBSTÂNCIA", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "lab_cnpj"] == emptyStr
        inifile["positions_pmc", "lab_cnpj"]        := pmcDatabase.getValueColumn("CNPJ", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "lab_name"] == emptyStr
        inifile["positions_pmc", "lab_name"]        := pmcDatabase.getValueColumn("LABORATÓRIO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "ggrem"] == emptyStr
        inifile["positions_pmc", "ggrem"]           := pmcDatabase.getValueColumn("CÓDIGO GGREM", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "ms"] == emptyStr
        inifile["positions_pmc", "ms"]              := pmcDatabase.getValueColumn("REGISTRO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "ean"] == emptyStr
        inifile["positions_pmc", "ean"]             := pmcDatabase.getValueColumn("EAN 1", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "ean2"] == emptyStr
        inifile["positions_pmc", "ean2"]            := pmcDatabase.getValueColumn("EAN 2", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "name"] == emptyStr
        inifile["positions_pmc", "name"]            := pmcDatabase.getValueColumn("PRODUTO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "presentation"] == emptyStr
        inifile["positions_pmc", "presentation"]    := pmcDatabase.getValueColumn("APRESENTAÇÃO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "class"] == emptyStr
        inifile["positions_pmc", "class"]           := pmcDatabase.getValueColumn("CLASSE TERAPÊUTICA", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "type"] == emptyStr
        inifile["positions_pmc", "type"]            := pmcDatabase.getValueColumn("TIPO DE PRODUTO (STATUS DO PRODUTO)", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "price_control"] == emptyStr
        inifile["positions_pmc", "price_control"]   := pmcDatabase.getValueColumn("REGIME DE PREÇO", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_untributed"] == emptyStr
        inifile["positions_pmc", "pf_untributed"]   := pmcDatabase.getValueColumn("PF Sem Impostos", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_0"] == emptyStr
        inifile["positions_pmc", "pf_0"]            := pmcDatabase.getValueColumn("PF 0%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_12"] == emptyStr
        inifile["positions_pmc", "pf_12"]           := pmcDatabase.getValueColumn("PF 12%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_17"] == emptyStr
        inifile["positions_pmc", "pf_17"]           := pmcDatabase.getValueColumn("PF 17%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_17_alc"] == emptyStr
        inifile["positions_pmc", "pf_17_alc"]       := pmcDatabase.getValueColumn("PF 17% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_17_5"] == emptyStr
        inifile["positions_pmc", "pf_17_5"]         := pmcDatabase.getValueColumn("PF 17,5%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_17_5_alc"] == emptyStr
        inifile["positions_pmc", "pf_17_5_alc"]     := pmcDatabase.getValueColumn("PF 17,5% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_18"] == emptyStr
        inifile["positions_pmc", "pf_18"]           := pmcDatabase.getValueColumn("PF 18%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_18_alc"] == emptyStr
        inifile["positions_pmc", "pf_18_alc"]       := pmcDatabase.getValueColumn("PF 18% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_19"] == emptyStr
        inifile["positions_pmc", "pf_19"]           := pmcDatabase.getValueColumn("PF 19%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_20"] == emptyStr
        inifile["positions_pmc", "pf_20"]           := pmcDatabase.getValueColumn("PF 20%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_21"] == emptyStr
        inifile["positions_pmc", "pf_21"]           := pmcDatabase.getValueColumn("PF 21%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pf_22"] == emptyStr
        inifile["positions_pmc", "pf_22"]           := pmcDatabase.getValueColumn("PF 22%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_0"] == emptyStr
        inifile["positions_pmc", "pmc_0"]           := pmcDatabase.getValueColumn("PMC 0%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_12"] == emptyStr
        inifile["positions_pmc", "pmc_12"]          := pmcDatabase.getValueColumn("PMC 12%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_17"] == emptyStr
        inifile["positions_pmc", "pmc_17"]          := pmcDatabase.getValueColumn("PMC 17%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_17_alc"] == emptyStr
        inifile["positions_pmc", "pmc_17_alc"]      := pmcDatabase.getValueColumn("PMC 17% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_17_5"] == emptyStr
        inifile["positions_pmc", "pmc_17_5"]        := pmcDatabase.getValueColumn("PMC 17,5%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_17_5_alc"] == emptyStr
        inifile["positions_pmc", "pmc_17_5_alc"]    := pmcDatabase.getValueColumn("PMC 17,5% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_18"] == emptyStr
        inifile["positions_pmc", "pmc_18"]          := pmcDatabase.getValueColumn("PMC 18%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_18_alc"] == emptyStr
        inifile["positions_pmc", "pmc_18_alc"]      := pmcDatabase.getValueColumn("PMC 18% ALC", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_19"] == emptyStr
        inifile["positions_pmc", "pmc_19"]          := pmcDatabase.getValueColumn("PMC 19%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_20"] == emptyStr
        inifile["positions_pmc", "pmc_20"]          := pmcDatabase.getValueColumn("PMC 20%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_21"] == emptyStr
        inifile["positions_pmc", "pmc_21"]          := pmcDatabase.getValueColumn("PMC 21%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pmc_22"] == emptyStr
        inifile["positions_pmc", "pmc_22"]          := pmcDatabase.getValueColumn("PMC 22%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "hospital_only"] == emptyStr
        inifile["positions_pmc", "hospital_only"]   := pmcDatabase.getValueColumn("RESTRIÇÃO HOSPITALAR", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "cap"] == emptyStr
        inifile["positions_pmc", "cap"]             := pmcDatabase.getValueColumn("CAP", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "confaz_87"] == emptyStr
        inifile["positions_pmc", "confaz_87"]       := pmcDatabase.getValueColumn("CONFAZ 87", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "icms_0"] == emptyStr
        inifile["positions_pmc", "icms_0"]          := pmcDatabase.getValueColumn("ICMS 0%", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "recursal"] == emptyStr
        inifile["positions_pmc", "recursal"]        := pmcDatabase.getValueColumn("ANÁLISE RECURSAL", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "pis_cofins"] == emptyStr
        inifile["positions_pmc", "pis_cofins"]      := pmcDatabase.getValueColumn("LISTA DE CONCESSÃO DE CRÉDITO TRIBUTÁRIO (PIS/COFINS)", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "commercialized"] == emptyStr
        inifile["positions_pmc", "commercialized"]  := pmcDatabase.getValueColumn("COMERCIALIZAÇÃO 2022", "40:" pmcDatabase.rowCount)
    progress += 1
    if inifile["positions_pmc", "stripe"] == emptyStr
        inifile["positions_pmc", "stripe"]          := pmcDatabase.getValueColumn("TARJA", "40:" pmcDatabase.rowCount)
    progress += 1

    load.stop()
}

deleteDatabases(args*) {
    try {
        FileDelete(instalationDir "\*.xls")
    }
}

corruptDatabases(args*) {
    inifile["databases", "pmc_name"] := "Error"
    inifile["databases", "pmc_path"] := "Error"
    inifile["databases", "pmc_url"] := "Error"
    ExitApp(FailedToGetDatabase)
}

installPmcDatabase() {
    progress := 0
    mProgress := 6

    load := loadingScreen("Instalando banco de dados PMC...", repository " por " author, &progress, mProgress)
    load.start()

    try {
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

getPmcDatabaseName() {
    if pmcDatabaseUrl == emptyStr
        return emptyStr
    name := StrSplit(pmcDatabaseUrl, "arquivos/")[2]
    name := StrSplit(name, "/")[1]

    return name
}

getPmcDatabaseUrl() {
    if not InStr(cmedHtml, "Preço máximo") {
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

getItemFromEan(ean) {
    eanColumn := inifile["positions_pmc", "ean"]
    eanColumn .= ":" eanColumn

    item := ItemClass()
    item.getItemFromRow(pmcDatabase.getValueRow(ean, eanColumn))
    return item
}

getListOfItemsByDesc(desc, method) {
    items := Map()
    lastRow := "1"
    rowCount := pmcDatabase.rowCount
    maxItems := inifile["config", "max_items_on_list", 100]
    nameCol := inifile["positions_pmc", "name"]
    compCol := inifile["positions_pmc", "composition"]
    eanCol := inifile["positions_pmc", "ean"]
    lab_name := StrSplit(desc, " LAB:")
    lab_name := InStr(desc, " LAB:") ? lab_name[2] : emptyStr
    if lab_name != emptyStr{
        desc := StrSplit(desc, " LAB:")
        desc := desc[1]
    }

    if method == "Name"{
        l := loadingScreen("Buscando por nome", repository " por " author, &lastRow, rowCount)
        l.start()
        loop {
            itemsCount := items.Count
            row := pmcDatabase.getValueRow(desc, nameCol lastRow ":" nameCol rowCount)
            if not row or (itemsCount >= maxItems and maxItems != 0) or row == lastRow
                break

            item := ItemClass()
            item.getItemFromRow(row)
            if not IsNumber(item.ean){
                lastRow := row
                continue
            }
            if lab_name != emptyStr{
                if InStr(item.lab_name, lab_name)
                    items[row] := item
            }
            else{
                items[row] := item
            }
            lastRow := row
        }
        l.stop()
    }
    else{
        l := loadingScreen("Buscando por composicao", repository " por " author, &lastRow, rowCount)
        l.start()
        loop {
            itemsCount := items.Count
            row := pmcDatabase.getValueRow(desc, compCol lastRow ":" compCol rowCount)
            if not row or (itemsCount >= maxItems and maxItems != 0) or row == lastRow
                break
    
            item := ItemClass()
            item.getItemFromRow(row)
            if not IsNumber(item.ean){
                lastRow := row
                continue
            }
            if lab_name != emptyStr{
                if InStr(item.lab_name, lab_name)
                    items[row] := item
            }
            else{
                items[row] := item
            }
            lastRow := row
        }
        l.stop()
    }
    return items
}

showListOfItems(itemsMap) {
    gItems := Gui("-MaximizeBox", "Lista de itens")
    LV := gItems.AddListView("r20 w1000", ["Codigo de barras", "Nome", "Composicao", "Apresentacao", "Laboratorio",
        "Tipo", "Preco", "PF", "PMC", "Lista"])
    LV.OnEvent("DoubleClick", doubleClickedItem)
    resultsN := gItems.AddText("xm20", "Quantidade de resultados: " itemsMap.Count)

    for row, item in itemsMap {
        pf := item.type == "Genérico" ? item.pf_12 : item.pf_18
        pmc := item.type == "Genérico" ? item.pmc_12 : item.pmc_18

        LV.Add(, item.ean, item.name, item.composition, item.presentation, item.lab_name, item.type,
            item.price_control, pf, pmc, item.pis_cofins)
    }

    LV.ModifyCol
    LV.ModifyCol(5, "Integer")
    LV.ModifyCol(8, "Float")
    LV.ModifyCol(9, "Float")
    gItems.Show()
}

doubleClickedItem(LV, RowNumber) {
    item := getItemFromEan(LV.GetText(RowNumber))
    showItem(item)
}

showItem(item) {
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
    gtxtPf.Text     .= item.type == "Genérico" ? item.pf_12 : item.pf_18
    gtxtPmc         := gItem.AddText("xm5", "Preco Maximo Consumidor:`n")
    gtxtPmc.Text    .= item.type == "Genérico" ? item.pmc_12 : item.pmc_18
    gtxtPisCofins   := gItem.AddText("xm5", "Lista PIS/COFINS:`n" item.pis_cofins)

    gItem.Show()
}

exitFunc(args*) {
    try {
        pmcDatabase.close()
    }

}

class ItemClass {
    __New() {
        this.row_on_database    := ""
        this.composition        := ""
        this.lab_cnpj           := ""
        this.lab_name           := ""
        this.ggrem              := ""
        this.ms                 := ""
        this.ean                := ""
        this.ean2               := ""
        this.name               := ""
        this.presentation       := ""
        this.class              := ""
        this.type               := ""
        this.price_control      := ""
        this.pf_untributed      := ""
        this.pf_0               := ""
        this.pf_12              := ""
        this.pf_17              := ""
        this.pf_17_alc          := ""
        this.pf_17_5            := ""
        this.pf_17_5_alc        := ""
        this.pf_18              := ""
        this.pf_18_alc          := ""
        this.pf_19              := ""
        this.pf_20              := ""
        this.pf_21              := ""
        this.pf_22              := ""
        this.pmc_0              := ""
        this.pmc_12             := ""
        this.pmc_17             := ""
        this.pmc_17_alc         := ""
        this.pmc_17_5           := ""
        this.pmc_17_5_alc       := ""
        this.pmc_18             := ""
        this.pmc_18_alc         := ""
        this.pmc_19             := ""
        this.pmc_20             := ""
        this.pmc_21             := ""
        this.pmc_22             := ""
        this.hospital_only      := ""
        this.cap                := ""
        this.confaz_87          := ""
        this.icms_0             := ""
        this.recursal           := ""
        this.pis_cofins         := ""
        this.commercialized     := ""
        this.stripe             := ""
    }

    getItemFromRow(row := this.row_on_database) {
        if not row
            return false
        this.composition    := pmcDatabase.getValue(inifile["positions_pmc", "composition"] row)
        this.lab_cnpj       := pmcDatabase.getValue(inifile["positions_pmc", "lab_cnpj"] row)
        this.lab_name       := pmcDatabase.getValue(inifile["positions_pmc", "lab_name"] row)
        this.ggrem          := pmcDatabase.getValue(inifile["positions_pmc", "ggrem"] row)
        this.ms             := pmcDatabase.getValue(inifile["positions_pmc", "ms"] row)
        this.ean            := pmcDatabase.getValue(inifile["positions_pmc", "ean"] row)
        this.ean2           := pmcDatabase.getValue(inifile["positions_pmc", "ean2"] row)
        this.name           := pmcDatabase.getValue(inifile["positions_pmc", "name"] row)
        this.presentation   := pmcDatabase.getValue(inifile["positions_pmc", "presentation"] row)
        this.class          := pmcDatabase.getValue(inifile["positions_pmc", "class"] row)
        this.type           := pmcDatabase.getValue(inifile["positions_pmc", "type"] row)
        this.price_control  := pmcDatabase.getValue(inifile["positions_pmc", "price_control"] row)
        this.pf_untributed  := pmcDatabase.getValue(inifile["positions_pmc", "pf_untributed"] row)
        this.pf_0           := pmcDatabase.getValue(inifile["positions_pmc", "pf_0"] row)
        this.pf_12          := pmcDatabase.getValue(inifile["positions_pmc", "pf_12"] row)
        this.pf_17          := pmcDatabase.getValue(inifile["positions_pmc", "pf_17"] row)
        this.pf_17_alc      := pmcDatabase.getValue(inifile["positions_pmc", "pf_17_alc"] row)
        this.pf_17_5        := pmcDatabase.getValue(inifile["positions_pmc", "pf_17_5"] row)
        this.pf_17_5_alc    := pmcDatabase.getValue(inifile["positions_pmc", "pf_17_5_alc"] row)
        this.pf_18          := pmcDatabase.getValue(inifile["positions_pmc", "pf_18"] row)
        this.pf_18_alc      := pmcDatabase.getValue(inifile["positions_pmc", "pf_18_alc"] row)
        this.pf_19          := pmcDatabase.getValue(inifile["positions_pmc", "pf_19"] row)
        this.pf_20          := pmcDatabase.getValue(inifile["positions_pmc", "pf_20"] row)
        this.pf_21          := pmcDatabase.getValue(inifile["positions_pmc", "pf_21"] row)
        this.pf_22          := pmcDatabase.getValue(inifile["positions_pmc", "pf_22"] row)
        this.pmc_0          := pmcDatabase.getValue(inifile["positions_pmc", "pmc_0"] row)
        this.pmc_12         := pmcDatabase.getValue(inifile["positions_pmc", "pmc_12"] row)
        this.pmc_17         := pmcDatabase.getValue(inifile["positions_pmc", "pmc_17"] row)
        this.pmc_17_alc     := pmcDatabase.getValue(inifile["positions_pmc", "pmc_17_alc"] row)
        this.pmc_17_5       := pmcDatabase.getValue(inifile["positions_pmc", "pmc_17_5"] row)
        this.pmc_17_5_alc   := pmcDatabase.getValue(inifile["positions_pmc", "pmc_17_5_alc"] row)
        this.pmc_18         := pmcDatabase.getValue(inifile["positions_pmc", "pmc_18"] row)
        this.pmc_19         := pmcDatabase.getValue(inifile["positions_pmc", "pmc_19"] row)
        this.pmc_20         := pmcDatabase.getValue(inifile["positions_pmc", "pmc_20"] row)
        this.pmc_21         := pmcDatabase.getValue(inifile["positions_pmc", "pmc_21"] row)
        this.pmc_22         := pmcDatabase.getValue(inifile["positions_pmc", "pmc_22"] row)
        this.hospital_only  := pmcDatabase.getValue(inifile["positions_pmc", "hospital_only"] row)
        this.cap            := pmcDatabase.getValue(inifile["positions_pmc", "cap"] row)
        this.confaz_87      := pmcDatabase.getValue(inifile["positions_pmc", "confaz_87"] row)
        this.icms_0         := pmcDatabase.getValue(inifile["positions_pmc", "icms_0"] row)
        this.recursal       := pmcDatabase.getValue(inifile["positions_pmc", "recursal"] row)
        this.pis_cofins     := pmcDatabase.getValue(inifile["positions_pmc", "pis_cofins"] row)
        this.commercialized := pmcDatabase.getValue(inifile["positions_pmc", "commercialized"] row)
        this.stripe         := pmcDatabase.getValue(inifile["positions_pmc", "stripe"] row)
    }
}

loading.stop()