# nha-validering
Denne pakken inneholder valideringsverktøy for å sjekke avleveringer før de sendes til NHA. For fysiske avleveringer er det i hovedsak *valider-avlxml* som skal benyttes, og elektroniske journalarkiver kjøres *valider-epjark*. I tillegg til disse to ligger det enkelte verktøy som kun ser på deler av en avlevering, og disse kan brukes under feilsøking hvis hovedvalideringen feiler.

## Forutsetninger
Valideringsverktøyene er skrevet som bash-script og må kjøres i en omgivelse som støtter dette. For Windows-brukere innebærer dette å kjøre under Windows Subsystem for Linux (WSL) eller en annen form for virtuell maskin som kjører linux. Mac OSX støtter bash og verktøyene kan kjøres fra et terminalvindu.

I tillegg forutsettes det at følgende verktøy er installert:
- xmlstarlet
- xmllint
- md5sum
- paste
- sed

## Verktøy
### valider-avlxml.sh
Validering av en avleveringsliste (avlxml-<oid>.xml), både for fysiske og elektroniske avleveringer. Verktøyet sjekker strukturen i filen mot definerte skjemaer og kontrollerer informasjon i enkeltjournaler mot mors-regler for å luke ut potensielle vita-journaler.
### valider-epjark.sh
Sjekker om en mappe med et sett elektroniske pasientjournaler er konsistent. Dette verktøyet vil også kjøre *valider-avlxml*, *valider-epj-pakkeliste* og *valider-epj*.
MERK: I gjeldende versjon sjekkes ikke dokumentpakker.
### valider-epj-pakkeliste
Kjøres som en del av *valider-epjark*, men kan også kjøres alene. Verktøyertsjekker at strukturen i pakkelisten er i henhold til definert skjema, og kontrollerer sjekksummer for alle journalene som står i listen.
### valider-epj
Kjøres som en del av *valider-epjark*, men kan også kjøres alene for å kontrollere en enkelt elektronisk pasientjournal.

## Avlevering av fysiske pasientjournaler
For fysiske pasientjournaler er det kun *valider-avlxml* som skal benyttes. Dette gjelder både ved innsending av avleveringsforslag og faktiske avleveringer.

## Avlevering av elektroniske pasientjournaler
Elektroniske pasientjournaler er maskinelt behandlet, og det forutsettes at systemet som leverer ut arkiver i denne formen gjør tilstrekkelig validering før materialet gjøres klar for avlevering. I pilotfasen vil det imidlertid være nyttig om alt digitalt materiale, både testdata og reelle journaler, blir validert hos avsender før forsendelse.
