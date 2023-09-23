#Requires AutoHotkey v2.0
#SingleInstance Force
#Include <Bruno-Functions\ImportAllList>
#Include <GithubReleases\GithubReleases>

version         := "v0.0.1"

;--------some info--------------
author          := "TheBrunoCA"
git_repo        := "BuscaPMC"
github          := GithubReleases(author, git_repo)

is_updated      := true
try{
    is_updated  := github.IsUpToDate(version)
}

install_path    := A_AppData "\" author "\" git_repo "\"
db_path         := install_path "\pmc_db.csv"
ini_file        := Ini(install_path git_repo "_config.ini")
global_ini      := Ini(install_path "Global.ini")
if IsOnline{
    Download("https://drive.google.com/uc?export=download&id=1GYD0EoaJ1fA-hzpStBzf3ZWeMPOs7YbJ", global_ini.path)
}


;--------gui related info-------
ask_estate_gui_title    := version
main_gui_title          := git_repo " " version
main_gui_title          .= is_updated ? "" : "|| " github.GetLatestReleaseVersion() " available."
config_gui_title        := ""

;---------estates ini--------------
normal  := "NORMAL"
generico:= "GENERICO"
siglas  := "SIGLAS"

;---------config ini--------------
info    := "INFO"
    version         := "VERSION"
    db_version      := "DB_VERSION"
    last_db_update  := "LAST_DB_UPDATE"
    last_app_update := "LAST_APP_UPDATE"

config  := "CONFIG"
    estate          := "ESTATE"


FileInstall("Estados.ini", install_path "Estados.ini", true)
estates_ini := Ini(install_path "Estados.ini")
siglas      := StrSplit(estates_ini[siglas], "`n")

is_excel_installed := IsExcelInstalled()
is_estate_defined := ini_file[config, estate] != ""

UpdateDatabase()
if not FileExist(db_path){
    MsgBox("Não existe banco de dados baixado. Tente reabrir novamente.")
}

db := CsvHelper(db_path)

if not is_estate_defined {
    AskEstate()
}else
    MainGui()



;-------------------Functions------------------

UpdateDatabase(){
    if not IsOnline
        return

    if (ini_file[info, db_version] != global_ini[git_repo, "latest_database"]) or not FileExist(db_path){

        downloadFile(global_ini[git_repo, "pmc_csv_link"], db_path, , , OnFailedDownload)

        ini_file[info, db_version] := global_ini[git_repo, "latest_database"]
        ini_file[info, last_db_update] := A_Now
    }
}

OnFailedDownload(args*){
    try{
        FileDelete(db_path)
        ExitApp()
    }
}

;------------------- GUIS ---------------------

AskEstate(args*){
    gui_estate  := Gui()
    gui_estate  .OnEvent("Close", _closedGui)
    ask_text    := gui_estate.AddText(, "Selecione a sigla do seu estado.")
    estate_ddl  := gui_estate.AddDropDownList(, siglas)
    submit_btn  := gui_estate.AddButton("Default", "Confirmar").OnEvent("Click", _saveEstate)
    _saveEstate(args*){
        if estate_ddl.Text == emptyStr
            return
        ini_file[config, estate] := estate_ddl.Text
        gui_estate.Destroy()
        if WinExist(main_gui_title)
            return
        MainGui()
    }
    _closedGui(args*){
        if ini_file[config, estate] != ""
            return
        ExitApp()
    }
    gui_estate.Show()
}

ConfigGui(args*){
    gui_config      := Gui(, config_gui_title)
    ask_estate_btn  := gui_config.AddButton(, "Selecionar Estado")
    ask_estate_btn.OnEvent("Click", AskEstate)

    gui_config.Show()
}

MainGui(){
    gui_main    := Gui(, main_gui_title)
    gui_main    .OnEvent("Close", _onClose)
    _onClose(args*){
        gui_main.Destroy()
    }
    search_text := gui_main.AddText(, "Digite o NOME, COMPOSIÇÃO ou CODIGO DE BARRAS")
    search_edit := gui_main.AddEdit("Uppercase w200")
    search_btn  := gui_main.AddButton("yp x+5 Default", "Buscar")
    search_btn  .OnEvent("Click", _searchBtn)
    _searchBtn(args*){
        if search_edit.Value == ""
            return
        if IsNumber(search_edit.Value){
            try{
                item := db.findItem(search_edit.Value, "EAN 1", true)
            } catch Error as e{
                if e.Message == "No item found with such attributes."{
                    MsgBox("Não foi encontrado nenhum item com esse codigo de barras.")
                    search_edit.Value := ""
                }
            }
            search_edit.Value := ""

            ItemGui(item)
            
            return
        }

    }
    config_btn  := gui_main.AddButton(, "Configurações")
    config_btn  .OnEvent("Click", _configBtn)
    _configBtn(args*){
        ConfigGui()
    }

    gui_main.Show()
}

ItemGui(item){
    generic := item["TIPO DE PRODUTO (STATUS DO PRODUTO)"] == "GENERICO" ? true : false
    aliq := generic ? estates_ini[generico, ini_file[config, estate]] 
    : estates_ini[normal, ini_file[config, estate]]

    itemgui := Gui()
    itemgui.AddText("xm", "Nome: ")
    itemgui.AddEdit("ReadOnly yp x+2", item["PRODUTO"] " " 
                                    item["APRESENTACAO"])
    itemgui.AddText("yp x+20", "Código de barras: ")
    itemgui.AddEdit("ReadOnly Number yp x+2", item["EAN 1"])
    itemgui.AddText("yp x+20", "Lista: " item["LISTA DE CONCESSAO DE CREDITO TRIBUTARIO (PIS/COFINS)"])
    itemgui.AddText("xm y+20", "Composição: ")
    itemgui.AddEdit("yp x+2 ReadOnly", item["SUBSTANCIA"])
    itemgui.AddText("yp x+20", "Laboratório: ")
    itemgui.AddEdit("yp x+2 ReadOnly", item["LABORATORIO"])
    itemgui.AddText("yp x+20", "Registro MS: ")
    itemgui.AddEdit("yp x+2 ReadOnly", item["REGISTRO"])
    itemgui.AddText("xm y+20", "Classe: ")
    itemgui.AddEdit("yp x+2 ReadOnly", item["CLASSE TERAPEUTICA"])
    itemgui.AddText("yp x+20", "Categoria: ")
    itemgui.AddEdit("yp x+2 ReadOnly", item["TIPO DE PRODUTO (STATUS DO PRODUTO)"])
    itemgui.AddText("yp x+20", "Regime: ")
    itemgui.AddEdit("yp x+2 ReadOnly", item["REGIME DE PRECO"])
    itemgui.AddText("xm y+20", "Preço Fábrica: ")
    itemgui.AddEdit("yp x+2 ReadOnly", "R$" item["PF " aliq])
    itemgui.AddText("yp x+20", "Preço Máximo: ")
    itemgui.AddEdit("yp x+2 ReadOnly", "R$" item["PMC " aliq])

    itemgui.Show()
}