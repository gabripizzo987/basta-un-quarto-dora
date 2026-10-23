extends Node
## Collegamento con Google Play Games (accesso + classifica mondiale).
##
## Parla direttamente con la parte Android del plugin "GodotPlayGameServices"
## usando metodi con nome (niente lambda nelle .connect(), che su Android crashano).
## Su PC o senza plugin non fa niente: il gioco funziona lo stesso.

signal signed_in_changed(is_signed_in: bool)

## ID della classifica creata nella Play Console
## (Play Games Services -> Classifiche). Esempio: "CgkI8a2b3c4dEAIQAQ"
const LEADERBOARD_ID := "CgkI3bjJ188fEAIQAQ"

const PLUGIN_NAME := "GodotPlayGameServices"
const SAVE_PATH := "user://punteggio.cfg"

var is_signed_in: bool = false
var best_score: int = 0

var _plugin: Object = null
var _pending_score: int = -1
var _open_leaderboard_after_sign_in: bool = false


func _ready() -> void:
	_load_best_score()

	if not Engine.has_singleton(PLUGIN_NAME):
		print("[PlayGames] plugin non trovato: classifica disattivata (normale su PC)")
		return

	_plugin = Engine.get_singleton(PLUGIN_NAME)
	_plugin.initialize()
	_plugin.userAuthenticated.connect(_on_user_authenticated)
	_plugin.scoreSubmitted.connect(_on_score_submitted)

	# Play Games v2 fa l'accesso da solo all'avvio: qui chiediamo solo com'e' andata.
	_plugin.isAuthenticated()


func is_available() -> bool:
	return _plugin != null and LEADERBOARD_ID != ""


## Accesso manuale (es. se l'utente aveva rifiutato all'avvio).
func sign_in() -> void:
	if _plugin != null:
		_plugin.signIn()


## Salva il record locale e, se possibile, invia il punteggio alla classifica.
## La classifica di Google tiene da sola il punteggio migliore di ogni giocatore.
func submit_score(score: int) -> void:
	if score > best_score:
		best_score = score
		_save_best_score()

	if not is_available():
		return

	if is_signed_in:
		_plugin.submitScore(LEADERBOARD_ID, score)
	else:
		# lo inviamo appena l'utente accede
		_pending_score = maxi(_pending_score, score)


func show_leaderboard() -> void:
	if not is_available():
		return
	if is_signed_in:
		_plugin.showLeaderboard(LEADERBOARD_ID)
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

	if LEADERBOARD_ID == "":
		return

	# invia il record locale (anche partite fatte prima di accedere)
	var to_send := maxi(_pending_score, best_score)
	if to_send > 0:
		_plugin.submitScore(LEADERBOARD_ID, to_send)
	_pending_score = -1

	if _open_leaderboard_after_sign_in:
		_open_leaderboard_after_sign_in = false
		_plugin.showLeaderboard(LEADERBOARD_ID)


func _on_score_submitted(is_submitted: bool, leaderboard_id: String) -> void:
	print("[PlayGames] punteggio inviato: ", is_submitted, " (", leaderboard_id, ")")


func _load_best_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("score", "best", 0))


func _save_best_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best_score)
	cfg.save(SAVE_PATH)
