#Requires AutoHotkey v2.0
#SingleInstance Force
#Include <Bruno-Functions\ImportAllList>
#Include <GithubReleases\GithubReleases>

version := "v0.0.1"

;--------some info--------------
author := "TheBrunoCA"
git_repo := "BuscaPMC"
github := GithubReleases(author, git_repo)

is_updated := true
try {
    is_updated := github.IsUpToDate(version)
}

install_path := A_AppData "\" author "\" git_repo "\"
db_path := install_path "\pmc_db.csv"
ini_file := Ini(install_path git_repo "_config.ini")
global_ini := Ini(install_path "Global.ini")
if IsOnline {
    Download("https://drive.google.com/uc?export=download&id=1InFU70diEoe1OLCCOUQNMtPmg9_Way54", global_ini.path)
}


;--------gui related info-------
ask_estate_gui_title    := version
main_gui_title          := git_repo " " version
main_gui_title          .= is_updated ? "" : "|| " github.GetLatestReleaseVersion() " available."
config_gui_title        := ""
item_gui_title          := ""
item_list_title         := ""

;---------estates ini--------------
normal := "NORMAL"
generico := "GENERICO"
siglas := "SIGLAS"

;---------config ini--------------
info := "INFO"
version := "VERSION"
db_version := "DB_VERSION"
last_db_update := "LAST_DB_UPDATE"
last_app_update := "LAST_APP_UPDATE"

config := "CONFIG"
estate := "ESTATE"


FileInstall("Estados.ini", install_path "Estados.ini", true)
estates_ini := Ini(install_path "Estados.ini")
siglas := StrSplit(estates_ini[siglas], "`n")

is_excel_installed := IsExcelInstalled()
is_estate_defined := ini_file[config, estate] != ""

UpdateDatabase()
if not FileExist(db_path) {
    MsgBox("Não existe banco de dados baixado. Tente reabrir novamente.")
}

db := CsvHelper(db_path)

if not is_estate_defined {
    AskEstate()
} else
    MainGui()


;-------------------Functions------------------

UpdateDatabase() {
    if not IsOnline
        return

    if (ini_file[info, db_version] != global_ini[git_repo, "latest_database"]) or not FileExist(db_path) {

        downloadFile(global_ini[git_repo, "pmc_csv_link"], db_path, , , OnFailedDownload)

        ini_file[info, db_version] := global_ini[git_repo, "latest_database"]
        ini_file[info, last_db_update] := A_Now
    }
}

OnFailedDownload(args*) {
    try {
        FileDelete(db_path)
        ExitApp()
    }
}

;------------------- GUIS ---------------------

AskEstate(args*) {
    gui_estate := Gui()
    gui_estate.OnEvent("Close", _closedGui)
    ask_text := gui_estate.AddText(, "Selecione a sigla do seu estado.")
    estate_ddl := gui_estate.AddDropDownList(, siglas)
    submit_btn := gui_estate.AddButton("Default", "Confirmar").OnEvent("Click", _saveEstate)
    _saveEstate(args*) {
        if estate_ddl.Text == emptyStr
            return
        ini_file[config, estate] := estate_ddl.Text
        gui_estate.Destroy()
        if WinExist(main_gui_title)
            return
        MainGui()
    }
    _closedGui(args*) {
        if ini_file[config, estate] != ""
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
    itemgui.AddText(, item.ean1[2] ": ")
    itemgui.AddText(, item.lab_name[2] ": ")
    itemgui.AddText(, item.registry[2] ": ")
    itemgui.AddText(, item.type[2] ": ")
    itemgui.AddText(, item.class[2] ": ")
    itemgui.AddText(, item.price_type[2] ": ")
    itemgui.AddText(, item.GetPF(ini_file[config, estate])[2] ": ")
    itemgui.AddText(, item.GetPMC(ini_file[config, estate])[2] ": ")
    itemgui.AddText(, item.pis_cofins[2] ": ")
    itemgui.AddButton("y+20", "Voltar").OnEvent("Click", _onVoltar)
    _onVoltar(args*) {
        itemgui.Destroy()
    }
    itemgui.AddEdit("ReadOnly ys+45", item.GetName())
    itemgui.AddEdit("ReadOnly xp", item.ean1[3])
    itemgui.AddEdit("ReadOnly xp", item.ean1[3])
    itemgui.AddEdit("ReadOnly xp", item.lab_name[3])
    itemgui.AddEdit("ReadOnly xp", item.registry[3])
    itemgui.AddEdit("ReadOnly xp", item.type[3])
    itemgui.AddEdit("ReadOnly xp", item.class[3])
    itemgui.AddEdit("ReadOnly xp", item.price_type[3])
    itemgui.AddEdit("ReadOnly xp", "R$" item.GetPF(ini_file[config, estate])[3])
    itemgui.AddEdit("ReadOnly xp", "R$" item.GetPMC(ini_file[config, estate])[3])
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
        itemlv.Add(, i.ean1[3], i.type[3], i.GetName(), i.comp[3], i.GetPF(ini_file[config, estate])[3], 
        i.GetPMC(ini_file[config, estate])[3], i.lab_name[3], i.pis_cofins[3])
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
        this.lab_cnpj       := ["CNPJ", "Cnpj do laboratório", item_map["CNPJ"]]
        this.lab_name       := ["LABORATORIO", "Laboratório", item_map["LABORATORIO"]]
        this.ggrem          := ["CODIGO GGREM", "Codigo GGREM", item_map["CODIGO GGREM"]]
        this.registry       := ["REGISTRO", "Registro MS", item_map["REGISTRO"]]
        this.ean1           := ["EAN 1", "Código de barras", item_map["EAN 1"]]
        this.ean2           := ["EAN 2", "Código de barras 2", item_map["EAN 2"]]
        this.ean3           := ["EAN 3", "Código de barras 3", item_map["EAN 3"]]
        this.product        := ["PRODUTO", "Nome", item_map["PRODUTO"]]
        this.presentation   := ["APRESENTACAO", "Apresentação", item_map["APRESENTACAO"]]
        this.class          := ["CLASSE TERAPEUTICA", "Classe Terapêutica", item_map["CLASSE TERAPEUTICA"]]
        this.type           := ["TIPO DE PRODUTO (STATUS DO PRODUTO)", "Categoria", item_map["TIPO DE PRODUTO (STATUS DO PRODUTO)"]]
        this.price_type     := ["REGIME DE PRECO", "Regime de preço", item_map["REGIME DE PRECO"]]
        this.pf_untributed  := ["PF SEM IMPOSTOS", "PF sem tributo", item_map["PF SEM IMPOSTOS"]]
        this.pf_0           := ["PF 0", "Preço Fábrica 0", item_map["PF 0"]]
        this.pf_12          := ["PF 12", "Preço Fábrica 12", item_map["PF 12"]]
        this.pf_17          := ["PF 17", "Preço Fábrica 17", item_map["PF 17"]]
        this.pf_17_alc      := ["PF 17 ALC", "Preço Fábrica 17 Area Livre Comércio", item_map["PF 17 ALC"]]
        this.pf_17_5        := ["PF 17,5", "Preço Fábrica 17,5", item_map["PF 17,5"]]
        this.pf_17_5_alc    := ["PF 17,5 ALC", "Preço Fábrica 17,5 Area Livre Comércio", item_map["PF 17,5 ALC"]]
        this.pf_18          := ["PF 18", "Preço Fábrica 18", item_map["PF 18"]]
        this.pf_18_alc      := ["PF 18 ALC", "Preço Fábrica 18 Area Livre Comércio", item_map["PF 18 ALC"]]
        this.pf_19          := ["PF 19", "Preço Fábrica 19", item_map["PF 19"]]
        this.pf_20          := ["PF 20", "Preço Fábrica 20", item_map["PF 20"]]
        this.pf_21          := ["PF 21", "Preço Fábrica 21", item_map["PF 21"]]
        this.pf_22          := ["PF 22", "Preço Fábrica 22", item_map["PF 22"]]
        this.pmc_0          := ["PMC 0", "Preço Máximo 0", item_map["PMC 0"]]
        this.pmc_12         := ["PMC 12", "Preço Máximo 12", item_map["PMC 12"]]
        this.pmc_17         := ["PMC 17", "Preço Máximo 17", item_map["PMC 17"]]
        this.pmc_17_alc     := ["PMC 17 ALC", "Preço Máximo 17 Area Livre Comércio", item_map["PMC 17 ALC"]]
        this.pmc_17_5       := ["PMC 17,5", "Preço Máximo 17,5", item_map["PMC 17,5"]]
        this.pmc_17_5_alc   := ["PMC 17,5 ALC", "Preço Máximo 17,5 Area Livre Comércio", item_map["PMC 17,5 ALC"]]
        this.pmc_18         := ["PMC 18", "Preço Máximo 18", item_map["PMC 18"]]
        this.pmc_18_alc     := ["PMC 18 ALC", "Preço Máximo 18 Area Livre Comércio", item_map["PMC 18 ALC"]]
        this.pmc_19         := ["PMC 19", "Preço Máximo 19", item_map["PMC 19"]]
        this.pmc_20         := ["PMC 20", "Preço Máximo 20", item_map["PMC 20"]]
        this.pmc_21         := ["PMC 21", "Preço Máximo 21", item_map["PMC 21"]]
        this.pmc_22         := ["PMC 22", "Preço Máximo 22", item_map["PMC 22"]]
        this.hospital_only  := ["RESTRICAO HOSPITALAR", "Uso Hospitalar", item_map["RESTRICAO HOSPITALAR"]]
        this.cap            := ["CAP", "Cap", item_map["CAP"]]
        this.confaz_87      := ["CONFAZ 87", "Confaz 87", item_map["CONFAZ 87"]]
        this.icms_0         := ["ICMS 0", "ICMS 0", item_map["ICMS 0"]]
        this.recursal       := ["ANALISE RECURSAL", "Em análise recursal", item_map["ANALISE RECURSAL"]]
        this.pis_cofins     := ["LISTA DE CONCESSAO DE CREDITO TRIBUTARIO (PIS/COFINS)", "Lista", item_map["LISTA DE CONCESSAO DE CREDITO TRIBUTARIO (PIS/COFINS)"]]
        this.commercialized := ["COMERCIALIZACAO 2022", "Comercializado em 2022", item_map["COMERCIALIZACAO 2022"]]
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