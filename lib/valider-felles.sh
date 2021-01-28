#
# Bibliotek over funksjoner som kan brukes av alle validator skriptene.
#

#
# Sjekk at verktøy som skriptet trenger finnes
#
sjekk_verktoy() {
  for v in $* ; do
    which $v > /dev/null
    [ "$?" != "0" ] && { echo "FEIL: Trenger $v for å kjøre dette skriptet." ; exit 1; }
  done
}

#
# Avslutt med feilmelding
#
trap "exit 1" TERM
export SKRIPT_PID=$$

avslutt() {
    printf "$1" "$2" 1>&2
    kill -s TERM $SKRIPT_PID
    #exit 1
}

absolutt_filnavn() {
  # $1 : relativt filnavn
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

relativt_filnavn() {
    python -c "import os.path; print os.path.relpath('$1', '$2')"
}


temp_katalog() {
    [ "$TMPDIR" != "" ] && tmpdir="$TMPDIR/XXXXXX"
    mktemp -d $tmpdir || { avslutt "$0: Klarte ikke lage temp katalog her: $tmpdir.\n";  }
}

fil_dato() {
    date -r $1 "+%Y-%m-%d" || { avslutt "Klarte ikke lese fil dato.\n";  }
}

premis_dato() {
    date '+%Y-%m-%dT%T.0%z'
}

dato() {
    date '+%Y-%m-%d'
}

uuid_regexp='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

er_uuid() {
    echo $1 | grep -q -E '^'"$uuid_regexp"'$'
}

#
# Hjelpefunksjoner for datoformater
#

function normaliser_dato() {
    local __datoTegn=${#1}
    local __resultatVariabel=$2
    local __yyyy=""
    local __mm=""
    local __dd=""
    if [ $__datoTegn -eq 10 ] && [ "${1:4:1}" == "-" ] && [ "${1:7:1}" == "-" ] ; then
        #YYYY-MM-DD
        __yyyy=${1:0:4}
        __mm=${1:5:2}
        __dd=${1:8:2}
    elif [ $__datoTegn -eq 8 ] ; then
        #YYYYMMDD
        __yyyy=${1:0:4}
        __mm=${1:4:2}
        __dd=${1:6:2}
    elif [ $__datoTegn -eq 7 ] && [ "${1:4:1}" == "-" ] ; then
        #YYYY-MM
        __yyyy=${1:0:4}
        __mm=${1:5:2}
        __dd="01"
    elif [ $__datoTegn -eq 4 ] ; then
        #YYYY
        __yyyy=${1:0:4}
        __mm="01"
        __dd="01"
    fi 

    if [[ $__yyyy$__mm$__dd =~ ^[0-9]+$ ]] ; then
        eval $__resultatVariabel="'$__yyyy-$__mm-$__dd'"
    else
        eval $__resultatVariabel="''"
    fi
}

function dato_til_aar() {
    local __normalisertDato=""
    normaliser_dato "$1" __normalisertDato

    if [[ "$__normalisertDato" != "" ]] ; then
        local __aarstall=$(date -d "$__normalisertDato 12:00:00" +%Y 2> /dev/null)
        eval $2="'$__aarstall'"
    else
        eval $2="''"
    fi
}

#
# Skriptene genererer en rapport på CppUnit XML format, dette gjør at testene kan vises av feks Jenkins byggeserver
#

# <?xml version="1.0"?>
# <TestRun>
#   <FailedTests></FailedTests>
#   <SuccessfulTests>
#     <Test id="1">
#       <Name>TestBasicMath::testAddition</Name>
#     </Test>
#     <Test id="2">
#       <Name>TestBasicMath::testMultiply</Name>
#     </Test>
#   </SuccessfulTests>
#   <Statistics>
#     <Tests>2</Tests>
#     <FailuresTotal>0</FailuresTotal>
#     <Errors>0</Errors>
#     <Failures>0</Failures>
#   </Statistics>
# </TestRun>

rapport_start() {
    testnr=0
cat << EOF > "$1"
<?xml version="1.0"?>
<TestRun>
EOF
}

rapport_slutt() {
cat << EOF >> "$1"
  <FailedTests>
$(for f in "${feil[@]}"; do echo "    $f"; done)
  </FailedTests>
  <SuccessfulTests>
$(for o in "${ok[@]}"; do echo "    $o"; done)
  </SuccessfulTests>
  <IgnoredTests>
$(for i in "${ignorert[@]}"; do echo "    $i"; done)
  </IgnoredTests>
  <Statistics>
    <Tests>$testnr</Tests>
    <FailuresTotal>${#feil[@]}</FailuresTotal>
    <Errors>${#feil[@]}</Errors>
    <Ignored>${#ignorert[@]}</Ignored>
    <Failures>0</Failures>
  </Statistics>
</TestRun>
EOF

  # Skriv rapport til skjerm
  [ "$2" == "1" ] && cat $1
}

rapport_ok() {
    testnr=$((testnr+1))
    local m=`printf "<Test id='$testnr'><Name>$1: $2</Name></Test>\n"`
    ok+=("$m")
}

rapport_feil() {
    testnr=$((testnr+1))
    local m=`printf "<Test id='$testnr'><Name>$1: $2</Name><Result>$3</Result></Test>\n"`
    feil+=("$m")
}

rapport_ignorert() {
    testnr=$((testnr+1))
    local m=`printf "<Test id='$testnr'><Name>$1: $2</Name></Test>\n"`
    ignorert+=("$m")
}

valider_shell() {
    #echo $validator
    validatorresultat=$(eval $validator 2>&1)
    local res="$?"
    if [ "$res" == "0" ] ; then
        rapport_ok $feilkode "$beskrivelse"
    else
        rapport_feil $feilkode "$beskrivelse" "$validatorresultat"
    fi
    return $res
}

# Regelfiler skal ha dette formatet (semikolon-separert liste)
# Feilkode Feltnavn Datatype Validator Kategori Type Innholdsbeskrivelse
#
# Kravtype: Angir type krav. Her brukes kodene:
#   O (Obligatorisk for både fysiske og elektroniske pasientjournaler)
#   F (Obligatorisk og aktuelt bare for fysiske pasientjournaler)
#   E (Obligatorisk og aktuelt bare for elektroniske pasientjournaler)
#   B (Betinget obligatorisk)
# Egendefinerte typer:
#   T Terminal - avslutter testingen

les_regler() {
    unset regellinjer
    while IFS= read -r linje
    do
        IFS=';' read -r -a felter <<< "$linje"
        navn="${felter[1]}"

        [ "$navn" == "$1" ] && regellinjer+=("$linje")
    done < "$regelfil"
}

valider_regler() {
    ##while IFS= read -r linje
    for linje in "${regellinjer[@]}"
    do
        #echo "$linje"
        IFS=';' read -r -a felter <<< "$linje"
        #echo "${felter[*]}"
        feilkode="${felter[0]}"
        #navn="${felter[1]}"
        validator=$(eval echo "\"${felter[3]}\"")
        type="${felter[5]}"
        beskrivelse=$(eval echo "\"${felter[6]}\"")        
        #echo $validator

        eval "$1"
    done 
}

function valider_filnavn() {
    # Søk etter ulovlige kataloger
    shopt -s extglob
    shopt -s nullglob
    ukjentfil=0

    for i in $validator; do
        rapport_feil $feilkode "$beskrivelse" $i
        ukjentfil=1
    done
    if [ "$ukjentfil" == "0" ] ; then
        rapport_ok $feilkode "$beskrivelse"
    fi
    shopt -u nullglob
    shopt -u extglob
}

function valider_jpg() {
    valider_shell
    [ "$?" != "0" ] && [ "$type" == "T" ] && { rapport_slutt $rapport $temprapport; exit ; }
}

function valider_xml() {
    valider_shell
    [ "$?" != "0" ] && [ "$type" == "T" ] && { rapport_slutt $rapport $temprapport; exit ; }
}

function les_avlxml()
{
    local __inn_mappe=$1
    local __ut_filnavn_var=$2
    local __ut_avlxmlid_var=$3

    local -a __avlxmlfiler=(`echo $__inn_mappe/avlxml-*.xml`)
    [ "${#__avlxmlfiler[@]}" == "0" ] && return 1;

    # Hvis det finnes flere avlxml, velg den siste ut fra dato-tag
    IFS=$'\n' __avlxmlfiler_sortert=($(sort <<<"${__avlxmlfiler[*]}")); unset IFS
    local __avlxml=${__avlxmlfiler_sortert[-1]}
    [ -f "$__avlxml" ] || return 1;

    local __avlxmlid=`xidel -s --xpath3 "/avlxml/avleveringsidentifikator" $__avlxml`

    eval $__ut_filnavn_var="'$__avlxml'"
    eval $__ut_avlxmlid_var="'$__avlxmlid'"
}

function err_array() {
    local __i=0
    local __msg=$1
    local __limit=$2
    shift 2
    local __arr=("$@")
    if [ ${#__arr[@]} -gt $__limit ] ; then
        >&2 echo "$__msg:"
        for e in "${__arr[@]}"; do
            >&2 echo "    ($__i): ${__arr[$__i]}"
            __i=$((__i+1))
        done
    fi
}

function limited_implode() {
    local __resultvar=$1
    local __limit=$2
    shift 2
    local __arr=("$@")

    if [ ${#__arr[@]} -gt $__limit ] ; then
        extras=$((${#__arr[@]}-$__limit))
        __arr=("${__arr[@]:0:$__limit}")
        __arr+=("...(+$extras tilsvarende feil)")
    fi

    local __imploded=$( IFS=','; echo "${__arr[*]}" );
    eval $__resultvar="'$__imploded'"
}

function oppdater_prod()
{
    local __respons
    __respons=$(production-set-status.php "$1" "$2" "$3" "$4" "$5" "$6" "$7")
    if [ $? -eq 0 ] ; then
        printf "$8\n"
    else
        printf "FEILET [Kunne ikke sette status '$8' i PROD]\n"
        >&2 echo "production-set-status.php('$1','$2','$3','$4','$5','$6') => $__respons"
    fi
}

#
# Tabeller som inneholder testresultat 
#
declare -a feil
declare -a feildetaljer
declare -a ok
declare -a ignorert
