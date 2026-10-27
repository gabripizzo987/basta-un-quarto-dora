extends Node
## Collegamento con Google Play Games (accesso + classifiche mondiali).
##
## Una classifica per ogni difficolta' (FACILE, MEDIO, DIFFICILE).
## Parla direttamente con la parte Android del plugin "GodotPlayGameServices"
## usando metodi con nome (niente lambda nelle .connect(), che su Android crashano).
## Su PC o senza plugin non fa niente: il gioco funziona lo stesso.

signal signed_in_changed(is_signed_in: bool)

## ID delle classifiche create nella Play Console
## (Play Games Services -> Classifiche), nell'ordine FACILE, MEDIO, DIFFICILE.
## Lasciare "" finche' la classifica non esiste: quella difficolta' non invia punteggi.
const LEADERBOARD_IDS: Array[String] = [
	"",                     # FACILE    (da creare)
	"CgkI3bjJ188fEAIQAQ",   # MEDIO     (la classifica "Punteggio" gia' esistente)
	"",                     # DIFFICILE (da creare)
]

const PLUGIN_NAME := "GodotPlayGameServices"
const SAVE_PATH := "user://punteggio.cfg"

var is_signed_in: bool = false
## Record personale per difficolta' (salvato sul telefono).
var best_scores: Array[int] = [0, 0, 0]

var _plugin: Object = null
var _pending: Array[int] = [-1, -1, -1]
var _open_leaderboard_after_sign_in: bool = false
var _reconnect_tried: bool = false


func _ready() -> void:
	_load_best_scores()

	if not Engine.has_singleton(PLUGIN_NAME):
		print("[PlayGames] plugin non trovato: classifica disattivata (normale su PC)")
		return

	_plugin = Engine.get_singleton(PLUGIN_NAME)
	_plugin.initialize()
	_plugin.userAuthenticated.connect(_on_user_authenticated)
	_plugin.scoreSubmitted.connect(_on_score_submitted)

	# Play Games v2 fa l'accesso da solo all'avvio: qui chiediamo solo com'e' andata.
	_plugin.isAuthenticated()


func _id_for(d: int) -> String:
	return LEADERBOARD_IDS[clampi(d, 0, LEADERBOARD_IDS.size() - 1)]


func _any_leaderboard() -> bool:
	for id in LEADERBOARD_IDS:
		if id != "":
			return true
	return false


func is_available() -> bool:
	return _plugin != null and _any_leaderboard()


func best_for(d: int) -> int:
	return best_scores[clampi(d, 0, best_scores.size() - 1)]


## Accesso manuale (es. se l'utente aveva rifiutato all'avvio).
func sign_in() -> void:
	if _plugin != null:
		_plugin.signIn()


## Salva il record locale e, se possibile, invia il punteggio alla classifica
## della difficolta' giocata. Google tiene da solo il migliore di ogni giocatore.
func submit_score(score: int) -> void:
	var d := clampi(RunState.difficulty, 0, 2)
	if score > best_scores[d]:
		best_scores[d] = score
		_save_best_scores()

	var id := _id_for(d)
	if _plugin == null or id == "":
		return

	_pending[d] = maxi(_pending[d], score)
	if is_signed_in:
		_plugin.submitScore(id, score)


## Apre l'elenco di tutte le classifiche (Facile, Medio, Difficile).
func show_leaderboard() -> void:
	if not is_available():
		return
	if is_signed_in:
		_plugin.showAllLeaderboards()
	else:
		_open_leaderboard_after_sign_in = true
		_plugin.signIn()


func _on_user_authenticated(authenticated: bool) -> void:
	is_signed_in = authenticated
	print("[PlayGames] accesso: ", authenticated)
	signed_in_changed.emit(authenticated)

	if not authenticated:
		_open_leaderboard_after_sign_in = false
		return

	# invia i record locali (anche partite fatte prima di accedere)
	for d in LEADERBOARD_IDS.size():
		var id := _id_for(d)
		var to_send := maxi(_pending[d], best_scores[d])
		if id != "" and to_send > 0:
			_plugin.submitScore(id, to_send)
		_pending[d] = -1

	if _open_leaderboard_after_sign_in:
		_open_leaderboard_after_sign_in = false
		_plugin.showAllLeaderboards()


func _on_score_submitted(is_submitted: bool, leaderboard_id: String) -> void:
	print("[PlayGames] punteggio inviato: ", is_submitted, " (", leaderboard_id, ")")
	if is_submitted:
		return

	# Errore 26502 (CLIENT_RECONNECT_REQUIRED): Google chiede di riconnettersi.
	# Facciamo UNA volta per avvio un accesso esplicito: al termine
	# _on_user_authenticated rimanda da solo i record.
	if not _reconnect_tried and _plugin != null:
		_reconnect_tried = true
		print("[PlayGames] invio fallito: provo a rifare l'accesso")
		_plugin.signIn()


func _load_best_scores() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for d in best_scores.size():
		best_scores[d] = int(cfg.get_value("score", "best_%d" % d, 0))
	# record della versione senza difficolta': era una partita "classica" -> MEDIO
	var old := int(cfg.get_value("score", "best", 0))
	if old > best_scores[1]:
		best_scores[1] = old


func _save_best_scores() -> void:
	var cfg := ConfigFile.new()
	for d in best_scores.size():
		cfg.set_value("score", "best_%d" % d, best_scores[d])
	cfg.save(SAVE_PATH)
