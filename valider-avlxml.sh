#!/usr/bin/env bash

#
# Valider innhold i AVLXML pakkeliste
#

PROGRAM_STI="`dirname \"$0\"`"                   # relativ sti
PROGRAM_STI="`( cd \"$PROGRAM_STI\" && pwd )`"   # absolutt og normalisert sti
if [ -z "$PROGRAM_STI" ] ; then
  echo "FEIL: Har ikke tilstrekkelige rettigheter for å lese fra $PROGRAM_STI"
  exit 1
fi

PATH=$PATH:$PROGRAM_STI
lib=$PROGRAM_STI/lib

source $lib/valider-felles.sh 2> /dev/null || { echo "FEIL: Finner ikke $lib/valider-felles.sh" ; exit 1; }

# Verktøy som trengs for å kjøre dette scriptet
sjekk_verktoy xmlstarlet xmllint

versjon="0.2.0"
program="${0##*/}"
kommando="$*"

vis_hjelp() {
cat << EOF
AVLXML validator versjon $versjon

Bruk: $program [opsjoner] <innfil>

Verktøy for validering av en avleveringsliste mot XML-sjema (XSD) og regler for innlemming i NHA (mors-regler).
MERK: Sjekk mot lokalt morsregister (LMR) er ikke tilgjengelig i denne versjonen, morsrapport basert kun på innhold i avlxml.

Opsjoner:
  
    -h|--hjelp  vis denne hjelpen og avslutt
    -f|--fpj    avleveringen beskriver en samling fysiske pasientjournaler
    -e|--epj    avleveringen beskriver en samling elektroniske pasientjournaler
    --les-avleveringsid
                les avleveringsidentifikator og avslutt
    --les-journalid
                les ut en liste med inneholdte journalidentifikatorer og avslutt
    --mors-rapport <rapport>
                valider enkeltjournaler opp mot regler for innlemming i NHA
    --skjema-rapport <rapport>
                generer rapport med resultat fra XSD-validering
    innfil      avleveringsliste som skal valideres

EOF
}

#
# Argumenter
#
FPJ=true
EPJ=false
VIS_AVLID=false
VIS_JOURNALID=false
xsdrapport="/dev/null"
lmrrapport="/dev/null"

#
# Les argumenter fra kommandolinjen
#
while :; do
    case $1 in
        -h|-\?|--hjelp)
            vis_hjelp    
            exit
            ;;
        --les-avleveringsid)
            VIS_AVLID=true
            ;;
        --les-journalid)
            VIS_JOURNALID=true
            ;;
        -e|--epj)
            EPJ=true
            FPJ=false
            ;;
        -f|--fpj)
            FPJ=true
            EPJ=false
            ;;
        --mors-rapport)
            if [ "$2" ]; then
                lmrrapport=$2
                shift
            else
                avslutt "FEIL: '$1' krever ett argument.\n"
            fi
            ;;
        --skjema-rapport)
            if [ "$2" ]; then
                xsdrapport=$2
                shift
            else
                avslutt "FEIL: '$1' krever ett argument.\n"
            fi
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            avslutt "FEIL: Ukjent parameter: $1\n"
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done

fil=$1
[ "$fil" == "" ]     && { vis_hjelp ; avslutt "FEIL: Må oppgi innfil!\n"; }
[ -f $fil ] ||  { avslutt "FEIL: Kan ikke åpne filen $fil\n"; }

if [ "$VIS_AVLID" == "true" ] ; then
    avlxmloid=`xmlstarlet sel -t -v "//_:avleveringsidentifikator" $fil 2>/dev/null`
    [ "$avlxmloid" == "" ] && { avslutt "FEIL: Fant ikke avleveringsidentifikator i $fil.\n"; }
    echo "$avlxmloid"
    exit 0
fi

if [ "$VIS_JOURNALID" == "true" ] ; then
    xmlstarlet sel -t -v "//_:journalidentifikator" -n $fil 2>/dev/null
    exit 0
fi

skjema="${PROGRAM_STI}/skjema/avlxml/avlxml.xsd"
[ -f $skjema ] ||  { avslutt "FEIL: Kan ikke åpne XSD-skjema $skjema\n"; }

#
# Valider mot skjema definert i avlxml.xsd
#
echo "Validerer mot XSD:"

xmllint --noout --schema $skjema $fil 2> $xsdrapport

if [ $? -ne 0 ] ; then 
    echo "  - Feil funnet under XSD-validering"
    if [ "$xsdrapport" == "/dev/null" ] ; then
        echo "  - Bruk '--skjema-rapport <rapport>' for å se hvorfor"
    else
        echo "  - Se '$xsdrapport' for detaljer"
    fi
else
    echo "  - OK"
fi

#
# Valider mot mors-definisjoner for innlemmelse i NHA
#
echo "Validerer mot mors-regler:"

cat << EOF > $lmrrapport
<?xml version='1.0'?>
<lmrrapport>
   <!-- LMR status koder:
        0  - OK : Validert mot LMR
        1  - OK : Validert ved morsdato
        2  - OK : Validert mot 110-års regel
        3  - OK : Validert mot 60-års regel
        4  - OK : Validert ved sikkermors
        10 - Ikke bekreftet mors
        11 - Mangler journalidentifikator
        12 - Feil i datoformat
        13 - Mangler fanearkidentifikator
    -->
EOF

declare -i ubekreftet=0
declare -i bekreftet=0
shopt -s lastpipe

xmlstarlet tr $lib/avlxml2csv.xsl "$fil" |
while IFS=";" read journalid fanearkid lagringsenhet fnr fodt mors sistekontakt sikkermors ; do
    declare -i kode=-1
    status=""

    # Sjekk at vi har en journalid finnes
    if [ "$journalid" == "" ] ; then 
        kode=11
        status="Mangler journalidentifikator"
    fi

    # Sjekk fanearkid for FPJ
    if [ $kode -lt 0 ] && eval $FPJ && [ "$fanearkid" == "" ] ; then
        kode=13
        status="Mangler fanearkidentifikator"
    fi

    # Sjekk datoformat (morsdato)
    norm_morsdato=""
    if [ $kode -lt 0 ] && [ "$mors" != "" ] ; then
        normaliser_dato "$mors" norm_morsdato
        if [ "$norm_morsdato" == "" ] ; then
            kode=12
            status="Feil datoformat [morsdato=$mors]"
        fi
    fi

    # Sjekk datoformat (fodtdato)
    fodt_aar=""
    if [ $kode -lt 0 ] && [ "$fodt" != "" ] ; then
        dato_til_aar "$fodt" fodt_aar
        if [ "$fodt_aar" == "" ] ; then
            kode=12
            status="Feil datoformat [fodtdato=$fodt]"
        fi
    fi

    # Sjekk datoformat (sistekontakt)
    sistekontakt_aar=""
    if [ $kode -lt 0 ] && [ "$sistekontakt" != "" ] ; then
        dato_til_aar "$sistekontakt" sistekontakt_aar
        if [ "$sistekontakt_aar" == "" ] ; then
            kode=12
            status="Feil datoformat [sistekontakt=$sistekontakt]"
        fi
    fi

    dette_aar=$(date +%Y 2> /dev/null)

    # Sjekk at morsdato er i fortid
    if [ $kode -lt 0 ] && [ "$mors" != "" ] ; then
        differanse_dager=$(( ( `date -d "$norm_morsdato" +%s` - `date -d "00:00" +%s`) / (24*3600) ))
        if [ $differanse_dager -le 0 ] ; then
            kode=1
            status="Validert ved morsdato"
        fi
    fi

    # Sjekk 110-års regel
    if [ $kode -lt 0 ] && [ "$fodt" != "" ] ; then
        diff=$(( dette_aar - fodt_aar ))
        if [ $diff -gt 110 ] ; then 
            kode=2
            status="Validert mot 110-års regel"
        fi
    fi

    # Sjekk 60-års regel
    if [ $kode -lt 0 ] && [ "$sistekontakt" != "" ] ; then
        diff=$(( dette_aar - sistekontakt_aar ))
        if [ $diff -gt 60 ] ; then 
            kode=3
            status="Validert mot 60-års regel"
        fi
    fi

    # Sjekk sikkermors
    if [ $kode -lt 0 ] && [ "$sikkermors" == "true" ] ; then
        kode=4
        status="Validert ved sikkermors"
    fi

    # Hvis ingen regler har slått til
    if [ $kode -lt 0 ] ; then
        kode=10
        status="Ikke bekreftet mors"
    fi

    if [ $kode -ge 10 ] ; then
        ubekreftet=$((ubekreftet+1))
    else
        bekreftet=$((bekreftet+1))
    fi

    echo "  <lmr journalidentifikator='$journalid' statuskode='$kode' status='$status'/>" >> $lmrrapport

done

echo "</lmrrapport>" >> $lmrrapport

if [ $ubekreftet -gt 1 ] ; then
    echo "  - $ubekreftet journaler kunne ikke verifiseres mot mors-regler"
else
    if [ $ubekreftet -eq 1 ] ; then
        echo "  - en journal kunne ikke verifiseres mot mors-regler"
    fi
fi

if [ $bekreftet -gt 1 ] ; then
    echo "  - $bekreftet journaler bekreftet mors"
else
    if [ $bekreftet -eq 1 ] ; then
        echo "  - en journal bekreftet mors"
    fi
fi

if [ "$lmrrapport" == "/dev/null" ] ; then
    echo "  MERK: Bruk '--mors-rapport <rapport>' for å generere en detaljert rapport"
else
    echo "  MERK: Se '$lmrrapport' for status på enkeltjournaler"
fi
