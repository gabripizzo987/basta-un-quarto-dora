# Crediti e attribuzioni — *Basta Un Quarto D'Ora*

Videogioco educativo sulla donazione del sangue, sviluppato in **Godot 4** da
**Gabriele Pizzo** come progetto di tesi/tirocinio.

---

## 1. Codice

Tutto il codice sorgente (script GDScript, logica di gioco, minigiochi, shader)
è **opera originale di Gabriele Pizzo**, rilasciato sotto licenza MIT — vedi
[`LICENSE`](LICENSE).

## 2. Audio (musica ed effetti sonori)

**Interamente originale.** Tutta la colonna sonora (temi chiptune delle stanze) e
tutti gli effetti sonori sono **generati proceduralmente via codice** in
`scripts/AudioManager.gd` (sintesi di onde quadre/triangolari, arpeggi, rumore).
**Nessun file audio di terze parti** è utilizzato.

## 3. Font

| Font | Autore | Licenza |
|------|--------|---------|
| **Inter** | Rasmus Andersson | SIL Open Font License 1.1 |
| **Montserrat** | Julieta Ulanovsky e il Montserrat Project | SIL Open Font License 1.1 |
| **Pixel Operator** (e varianti Mono/Bold/8) | Jayvee Enaguas (HarvettFox96) | CC0 1.0 (pubblico dominio) |

> 📌 **Nota OFL:** Inter e Montserrat sono sotto SIL Open Font License: includendo
> i `.ttf` nel progetto va incluso anche il testo della licenza. Copia il file
> `OFL.txt` (presente nello zip scaricato da Google Fonts) nella cartella
> [`fonts/`](fonts/). _(Se non lo trovi, posso generartelo io.)_

## 4. Grafica

### Personaggi (sprite 2D)
- **Universal LPC Spritesheet Character Generator**
  - File: `character-spritesheet*.png`, `player.png`, `walk.png`
  - Generatore: https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/
  - **Licenza: CC-BY-SA 3.0 / GPL-3.0 / OGA-BY 3.0 / CC0** (multi-licenza: ogni
    componente grafico — corpo, testa, capelli, vestiti, ecc. — ha autore e
    licenza propri).
  - **Attribuzione (obbligo CC-BY-SA / GPL):** l'elenco completo e dettagliato
    per ogni componente di ogni personaggio è incluso nel progetto:
    - [`credits/credits_personaggio_maschile.csv`](credits/credits_personaggio_maschile.csv)
    - [`credits/credits_personaggio_femminile.csv`](credits/credits_personaggio_femminile.csv)
  - **Artisti LPC (elenco completo, da entrambi i personaggi):**
    Stephen Challener (Redshrike), Johannes Sjölund (wulax), bluecarrot16,
    JaidynReiman, Eliza Wyatt (ElizaWy), Benjamin K. Smith (BenCreating),
    Matthew Krohn (makrohn), Thane Brimhall (pennomi), laetissima,
    Emilio J. Sanchez-Sierra, Pierre Vigier (pvigier), Durrani, Evert,
    TheraHedwig, MuffinElZangano.
  - **Nota licenza copyleft:** poiché alcuni componenti sono CC-BY-SA 3.0 / GPL-3.0
    (copyleft), gli sprite **derivati** dei personaggi ereditano quelle licenze.
    Questo **non** intacca la licenza MIT del tuo codice: riguarda solo i file
    grafici dei personaggi. I due CSV qui sopra soddisfano l'obbligo di
    attribuzione anche distribuendo solo l'APK.

### Interni, pareti, muri e pavimenti
- **"Modern Interiors" — di LimeZu**
  - File: `Interiors_free_32x32.png`, `Room_Builder_free_32x32.png`, `Floor_2_16x16.png`
  - Pagina: https://limezu.itch.io/moderninteriors
  - **Licenza:** uso in progetti commerciali e non commerciali consentito;
    modifiche consentite; **vietata la rivendita/ridistribuzione** degli asset.
  - **⚠️ Credito OBBLIGATORIO**, con link a **https://limezu.itch.io/**

### Tileset ospedale
- **"Top-Down Hospital" — di soppycraft**
  - File: `spritesheet_hospital_01/02/lab/maternity.png`
  - Pagina: https://soppycraft.itch.io/top-down-hospital
  - **Licenza:** gratuito; uso personale, commerciale ed **educativo** consentito;
    modifiche consentite; vietata la ridistribuzione del pack "as-is".
  - Credito non obbligatorio ma gradito (lo citiamo comunque).

### Interfaccia del manuale (Book UI) e freccia tutorial
- **Opera originale di Gabriele Pizzo.**
  - File: `assets/ui/book_ui_pixel.png` (sfondo libro del manuale),
    `assets/ui/arrow_pixel.png` (freccia indicatrice del tutorial).
  - **Licenza: MIT** (come il resto del progetto — vedi [`LICENSE`](LICENSE)).
  - Pixel-art generata proceduralmente via codice, nessun asset di terzi.
  - _Nota: sostituiscono i precedenti asset di terzi (Book UI di alonix e Arrows
    Pack di kenam0), rimossi dal progetto per avere piena titolarità in vista
    della distribuzione commerciale._

### Grafica generata con AI (ChatGPT / DALL·E)
Realizzata da **Gabriele Pizzo** tramite generazione AI. Secondo i termini di
OpenAI i diritti sugli output sono dell'autore. _(L'uso di AI generativa per
questi asset è dichiarato nella tesi.)_
- Sacche del sangue: `SaccaVuota.png`, `SaccaPiena.png`, `SaccaPiena-1*.png`,
  `Sacca.png`, `Sacca2.png`
- Mani: `ManoAperta.png`, `ManoChiusa.png`
- Vari: `Sfignomametro.png`, `Mouse.png`
- UI premi: `assets/ui/medals/bag_gold.png`, `bag_silver.png`, `bag_bronze.png`
- UI badge: `assets/ui/badges/precisione_ago.png`
- Tutti gli sfondi/elementi `ChatGPT Image *.png`

## 5. Fonti dei contenuti educativi
- **AVIS Senigallia — "Linee guida per la donazione"**
  - https://web.avissenigallia.it/linee-guida-per-la-donazione
  - Usata come fonte informativa per i contenuti su emocromo ed emoglobina.

## 6. Motore
- **Godot Engine 4** — © Juan Linietsky, Ariel Manzur e contributori — licenza MIT.

---

## ⚠️ Avvertenza sulla ridistribuzione

Diverse licenze (LimeZu, soppycraft, ecc.) **vietano di ridistribuire i file
grezzi** degli asset. In pratica:

- ✅ **Consegna della tesi e build del gioco (.apk / .exe):** nessun problema.
- ⚠️ **Repository pubblico (es. GitHub) con dentro i `.png` originali di terzi:**
  può violare la clausola "no redistribution" di LimeZu/soppycraft/ecc. Se
  pubblichi il sorgente, valuta di **escludere gli asset di terzi** dal repo
  (o tienilo privato).

Fa sempre fede **il testo di licenza sulla pagina ufficiale** di ciascun asset.
