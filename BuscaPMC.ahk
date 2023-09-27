#Requires AutoHotkey v2.0
#SingleInstance Force
#Include <Bruno-Functions\ImportAllList>
#Include <GithubReleases\GithubReleases>

version := "v0.0.1"

;--------some info--------------
author      := "TheBrunoCA"
git_repo    := "BuscaPMC"
site_url    := "http://www.thebrunoca.com.br/buscapmc/db/"
db_ini_url  := site_url "db.ini"
db_url      := site_url "db.csv"
github      := GithubReleases(author, git_repo)

is_updated  := true
try {
    is_updated := github.IsUpToDate(version)
}


install_path := A_AppData "\" author "\" git_repo "\"
db_path     := install_path "\db.csv"

config_file := Ini(install_path git_repo "_config.ini")
db_ini      := Ini(install_path "db.ini")


if IsOnline {
    Download(db_ini_url, db_ini.path)
}


;--------gui related info-------
ask_estate_gui_title    := version
main_gui_title          := git_repo " " version
main_gui_title          .= is_updated ? "" : "|| " github.GetLatestReleaseVersion() " available."
config_gui_title        := ""
item_gui_title          := ""
item_list_title         := ""


FileInstall("Estados.ini", install_path "Estados.ini", true)
estates_ini := Ini(install_path "Estados.ini")


UpdateDatabase()

if not FileExist(db_path) {
    MsgBox("Não existe banco de dados baixado. Tente reabrir quando houver internet.")
}

db := CsvHelper(db_path)

is_estate_defined := config_file["config", "estate"] != ""
if not is_estate_defined {
    AskEstate()
} else
    MainGui()


;-------------------Functions------------------

UpdateDatabase() {
    if not IsOnline
        return

    if not IsNumber(config_file["info", "db_last_updated"])
        config_file["info", "db_last_updated"] := 0

    if db_ini["db", "last_updated", 0] > config_file["info", "db_last_updated", 0] or 
        db_ini["db", "name"] != config_file["info", "db_name"] or 
        not FileExist(db_path){
            downloadFile(db_url, db_path, , , OnFailedDownload)
            config_file["info", "db_last_updated"] := db_ini["db", "last_updated"]
            config_file["info", "db_name"] := db_ini["db", "name"]
        }
}

OnFailedDownload(args*) {
    try {
        FileDelete(db_path)
        FileDelete(db_ini)
        ExitApp()
    }
}

;------------------- GUIS ---------------------

AskEstate(args*) {
    gui_estate := Gui(, ask_estate_gui_title)
    gui_estate.OnEvent("Close", _closedGui)
    ask_text := gui_estate.AddText(, "Selecione a sigla do seu estado.")
    estate_ddl := gui_estate.AddDropDownList(, estates_ini["siglas"])
    submit_btn := gui_estate.AddButton("Default", "Confirmar").OnEvent("Click", _saveEstate)
    _saveEstate(args*) {
        if estate_ddl.Text == emptyStr
            return
        config_file["config", "estate"] := estate_ddl.Text
        gui_estate.Destroy()
        if WinExist(main_gui_title)
            return
        MainGui()
    }
    _closedGui(args*) {
        if config_file["config", "estate"] != ""
            return
        ExitApp()
    }
    gui_estate.Show()
}

ConfigGui(args*) {
    gui_config := Gui(, config_gui_title)
    ask_estate_btn := gui_config.AddButton(, "Selecionar Estado")
    ask_estate_btn.OnEvent("Click", AskEstate)

    gui_config.Show()
}

MainGui() {
    gui_main := Gui(, main_gui_title)
    gui_main.OnEvent("Close", _onClose)
    _onClose(args*) {
        gui_main.Destroy()
    }
    search_text := gui_main.AddText(, "Digite o NOME, COMPOSIÇÃO ou CODIGO DE BARRAS")
    search_edit := gui_main.AddEdit("Uppercase w200")
    search_btn := gui_main.AddButton("yp x+5 Default", "Buscar")
    search_btn.OnEvent("Click", _searchBtn)
    _searchBtn(args*) {
        if search_edit.Value == ""
            return

        value := search_edit.Value
        search_edit.Value := ""

        if IsNumber(value) {
            try {
                item := db.findItem(value, "EAN 1", true)
                item := ItemClass(item)
            } catch Error as e {
                if e.Message == "No item found with such attributes." {
                    MsgBox("Não foi encontrado nenhum item com esse codigo de barras.")
                }
            }

            ItemGui(item)
            return
        }

        try {
            items := db.getArrayOfItems(value)
        } catch Error as e {
            if e.Message == "No item found with such attributes." {
                MsgBox("Não foi encontrado nenhum item com esse codigo de barras.")
            }
        }

        ItemListGui(items)
        return

    }
    config_btn := gui_main.AddButton(, "Configurações")
    config_btn.OnEvent("Click", _configBtn)
    _configBtn(args*) {
        ConfigGui()
    }

    gui_main.Show()
}

ItemGui(item) {

    itemgui := Gui(, item_gui_title)
    itemgui.SetFont("s12")
    itemgui.AddText("Center ym10", item.product[3])
    itemgui.SetFont("s10")
    itemgui.AddText("y+30", item.product[2] ": ")
    itemgui.AddText(, item.ean1[2] ": ")
    itemgui.AddText(, item.lab[2] ": ")
    itemgui.AddText(, item.registry[2] ": ")
    itemgui.AddText(, item.type[2] ": ")
    itemgui.AddText(, item.class[2] ": ")
    itemgui.AddText(, item.GetPF(config_file["config", "estate"])[2] ": ")
    itemgui.AddText(, item.GetPMC(config_file["config", "estate"])[2] ": ")
    itemgui.AddText(, item.pis_cofins[2] ": ")
    itemgui.AddButton("y+20", "Voltar").OnEvent("Click", _onVoltar)
    _onVoltar(args*) {
        itemgui.Destroy()
    }
    itemgui.AddEdit("ReadOnly ys+45", item.GetName())
    itemgui.AddEdit("ReadOnly xp", item.ean1[3])
    itemgui.AddEdit("ReadOnly xp", item.lab[3])
    itemgui.AddEdit("ReadOnly xp", item.registry[3])
    itemgui.AddEdit("ReadOnly xp", item.type[3])
    itemgui.AddEdit("ReadOnly xp", item.class[3])
    itemgui.AddEdit("ReadOnly xp", "R$" item.GetPF(config_file["config", "estate"])[3])
    itemgui.AddEdit("ReadOnly xp", "R$" item.GetPMC(config_file["config", "estate"])[3])
    itemgui.AddEdit("ReadOnly xp", item.pis_cofins[3])

    itemgui.Show()
}

ItemListGui(itemsArray){

    column := ["Código de barras", "Categoria", "Nome", "Composição", "PF", "PMC", "Laboratório", "Lista"]

    itemlist    := Gui(, item_list_title)
    itemlv      := itemlist.AddListView("w1000 h400", column)
    count       := itemlist.AddText(, "Resultados: " itemsArray.Length)

    for item in itemsArray{
        i := ItemClass(item)
        itemlv.Add(, i.ean1[3], i.type[3], i.GetName(), i.comp[3], i.GetPF(config_file["config", "estate"])[3], 
        i.GetPMC(config_file["config", "estate"])[3], i.lab[3], i.pis_cofins[3])
    }

    itemlv.ModifyCol()
    itemlv.ModifyCol(1, "Integer")
    itemlv.ModifyCol(5, "Float")
    itemlv.ModifyCol(6, "Float")

    itemlist.Show()
}



;----------------Classes-----------------



Class ItemClass{
    __New(item_map) {
        this.item           := item_map
        this.comp           := ["SUBSTANCIA", "Composição", item_map["SUBSTANCIA"]]
        this.lab            := ["LABORATORIO", "Laboratório", item_map["LABORATORIO"]]
        this.registry       := ["REGISTRO", "Registro MS", item_map["REGISTRO"]]
        this.ean1           := ["EAN 1", "Código de barras", item_map["EAN 1"]]
        this.ean2           := ["EAN 2", "Código de barras 2", item_map["EAN 2"]]
        this.product        := ["PRODUTO", "Nome", item_map["PRODUTO"]]
        this.presentation   := ["APRESENTACAO", "Apresentação", item_map["APRESENTACAO"]]
        this.class          := ["CLASSE TERAPEUTICA", "Classe Terapêutica", item_map["CLASSE TERAPEUTICA"]]
        this.type           := ["TIPO DE PRODUTO (STATUS DO PRODUTO)", "Categoria", item_map["TIPO DE PRODUTO (STATUS DO PRODUTO)"]]
        this.pf_12          := ["PF 12", "Preço Fábrica 12", item_map["PF 12"]]
        this.pf_17          := ["PF 17", "Preço Fábrica 17", item_map["PF 17"]]
        this.pf_17_5        := ["PF 17,5", "Preço Fábrica 17,5", item_map["PF 17,5"]]
        this.pf_18          := ["PF 18", "Preço Fábrica 18", item_map["PF 18"]]
        this.pf_19          := ["PF 19", "Preço Fábrica 19", item_map["PF 19"]]
        this.pf_20          := ["PF 20", "Preço Fábrica 20", item_map["PF 20"]]
        this.pf_21          := ["PF 21", "Preço Fábrica 21", item_map["PF 21"]]
        this.pf_22          := ["PF 22", "Preço Fábrica 22", item_map["PF 22"]]
        this.pmc_12         := ["PMC 12", "Preço Máximo 12", item_map["PMC 12"]]
        this.pmc_17         := ["PMC 17", "Preço Máximo 17", item_map["PMC 17"]]
        this.pmc_17_5       := ["PMC 17,5", "Preço Máximo 17,5", item_map["PMC 17,5"]]
        this.pmc_18         := ["PMC 18", "Preço Máximo 18", item_map["PMC 18"]]
        this.pmc_19         := ["PMC 19", "Preço Máximo 19", item_map["PMC 19"]]
        this.pmc_20         := ["PMC 20", "Preço Máximo 20", item_map["PMC 20"]]
        this.pmc_21         := ["PMC 21", "Preço Máximo 21", item_map["PMC 21"]]
        this.pmc_22         := ["PMC 22", "Preço Máximo 22", item_map["PMC 22"]]
        this.pis_cofins     := ["LISTA DE CONCESSAO DE CREDITO TRIBUTARIO (PIS/COFINS)", "Lista", item_map["LISTA DE CONCESSAO DE CREDITO TRIBUTARIO (PIS/COFINS)"]]
        this.stripe         := ["TARJA", "Tarja", item_map["TARJA"]]
    }

    GetName(){
        return this.product[3] " " this.presentation[3]
    }

    GetPF(estate){
        aliq := this._getAliq(estate)
        pf := ["PF " aliq, "Preço Fábrica " aliq, this.item["PF " aliq]]
        return pf
    }

    GetPMC(estate){
        aliq := this._getAliq(estate)
        pmc := ["PMC " aliq, "Preço Máximo " aliq, this.item["PMC " aliq]]
        return pmc
    }

    _getAliq(estate){
        section := this.type[3] == "GENERICO" ? "GENERICO" : "NORMAL"
        return IniRead(A_WorkingDir "\Estados.ini", section, estate)
    }
}