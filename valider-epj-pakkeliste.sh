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

source $lib/valider-felles.sh 2> /dev/null || { echo "FEIL: Finner ikke $/valider-felles.sh" ; exit 1; }

# Verktøy som trengs for å kjøre dette scriptet
sjekk_verktoy xmlstarlet xmllint md5sum paste sed

versjon="0.2.0"
program="${0##*/}"
kommando="$*"

vis_hjelp() {
cat << EOF
EPJ pakkeliste validator versjon $versjon

Bruk: $program [opsjoner] [fil]

Validerer en EPJ pakkeliste

Opsjoner:
    -l|--les-pakker  les epjpakkenavn og avlsutt  
    -h|--hjelp       vis denne hjelpen og avslutt
    fil              EPJ pakkeliste XML fil [default ./epjpakkeliste.xml]

EOF
}

VIS_PAKKER=false


#
# Les argumenter fra kommandolinjen
#
while :; do
    case $1 in
        -h|-\?|--hjelp)
            vis_hjelp    
            exit
            ;;
        -l|--les-pakker)
	        VIS_PAKKER=true
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

pakkeliste=$1
xmltool=xmlstarlet
if [[ "$pakkeliste" == "" ]] ; then
    pakkeliste="./epjpakkeliste.xml"
fi

if [ ! -f $pakkeliste ] ; then
    avslutt "FEIL: $pakkeliste finnes ikke!\n";
fi 

# AK4.2
# XML-filen skal være i henhold til skjema ”epjpakkeliste.xsd” som vedlikeholdes
# og distribueres av Norsk helsearkiv [17].
xsdkommando="xmllint --noout --schema $skjemaer/epj/epjpakkeliste.xsd $pakkeliste"
$xsdkommando 2> /dev/null
if [ $? != 0 ] ; then
    $xsdkommando 2>&1 | sed 's|{http://schema.arkivverket.no/epjark/epjpakkeliste}||g'
    avslutt "FEIL: $pakkeliste er ikke i henhold til XSD-skjema $skjemaer/epj/epjpakkeliste.xsd\n";
fi

if [ "$VIS_PAKKER" == "true" ] ; then
    $xmltool \
	sel -t -v "//*[local-name()='pakke']/*[local-name()='filReferanse']/text()" \
	$pakkeliste
    echo
    exit 0
fi

# AK4.5
# Alle avleveringspakker skal integritetssikres ved at det genereres en sjekksum
# iht. SHA-256 algoritmen.

# Hent ut filnavn og sjekksum, valider med md5sum
( cd $(dirname $pakkeliste) && \
  $xmltool \
    sel -t -v "//*[local-name()='pakke']/*[local-name()='filReferanse' or local-name()='sjekksum']/text()" \
    $(basename $pakkeliste) \
    | paste -d ' ' - - \
    | sed -e "s|^\(.*\) \(.*\)$|\2  \1|" \
    | md5sum -c - \
)
if [ $? != 0 ] ; then
    avslutt "FEIL: Sjekksumvalidering feilet!\n";
fi
