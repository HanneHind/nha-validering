#!/usr/bin/env bash

PROGRAM_STI="`dirname \"$0\"`"                   # relativ sti
PROGRAM_STI="`( cd \"$PROGRAM_STI\" && pwd )`"   # absolutt og normalisert sti
if [ -z "$PROGRAM_STI" ] ; then
  echo "FEIL: Har ikke tilstrekkelige rettigheter for å lese fra $PROGRAM_STI"
  exit 1
fi

PATH=$PATH:$PROGRAM_STI
lib=$PROGRAM_STI/lib
skjemaer=$PROGRAM_STI/skjema

source $lib/valider-felles.sh 2> /dev/null || { echo "FEIL: Finner ikke $lib/valider-felles.sh" ; exit 1; }

# Verktøy som trengs for å kjøre dette scriptet
#sjekk_verktoy xidel

versjon="0.2.0"
program="${0##*/}"
kommando="$*"

vis_hjelp() {
cat << EOF
EPJARK pakke validator versjon $versjon

Bruk: $program [opsjoner] <katalog> [<rapport>]

Validerer en EPJARK-katalog

Opsjoner:
    -h|--hjelp  vis denne hjelpen og avslutt
    katalog     EPJARK-katalog
    rapport     rapportfil som genereres, hvis ikke oppgitt skrives rapporten til standard utenhet

EOF
}


#
# Les argumenter fra kommandolinjen
#
while :; do
    case $1 in
        -h|-\?|--hjelp)
            vis_hjelp    
            exit
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            avslutt "FEIL: Unkjent parameter: $1\n"
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done

epjark=$1
rapport=$2

[ "$epjark" == "" ] && { vis_hjelp ; avslutt "FEIL: Må oppgi EPJARK katalog!\n"; }

avlxml=$(ls $epjark/avlxml*.xml)
epjpakkeliste=$(ls $epjark/epjpakkeliste*.xml)

regelfil="$lib/epjark.regler"

if [ "$rapport" == "" ] ; then
    rapport=$(mktemp /tmp/$program.XXXXX)
    temprapport=1
    trap "rm -f $rapport" EXIT
fi

rapport_start $rapport

[ ! -f "$regelfil" ] && { rapport_slutt $rapport; avslutt "FEIL: Finner ikke regelfilen $regelfil\n"; }

# Feilkode 	   Feltnavn	       Datatype	    Validator		Kategori     Type 	    Innholdsbeskrivelse
#
# Kravtype: Angir type krav. Her brukes kodene:
#   T Terminal - avslutter testingen

function valider_spj_shell() {
    valider_shell
    [ "$?" != "0" ] && [ "$type" == "T" ] && { rapport_slutt $rapport $temprapport; exit ; }
}

function valider_dok() {
    valider_shell
    [ "$?" != "0" ] && [ "$type" == "T" ] && { rapport_slutt $rapport $temprapport; exit ; }
}

les_regler "shell"
valider_regler "valider_spj_shell"

les_regler "dok"
for epjdokfil in ${epjdokfiler[@]}; do
    valider_regler "valider_dok"
done

# Valider EPJ-dok
#    tar xOf $epj $d | xmllint --noout --schema $skjema_dok -

rapport_slutt $rapport $temprapport

if [ "${#feil[@]}" != "0" ]; then
    avslutt "EPJ validerer ikke, se rapport for detaljer\n"
fi

