$userProfilePath = $env:USERPROFILE
$debug=0
function Normalize {
    param (
        [string]$string
    )
    $polishReplacements = @{
        '\u0105' = 'a'  # ą
        '\u0107' = 'c'  # ć
        '\u0119' = 'e'  # ę
        '\u0142' = 'l'  # ł
        '\u0144' = 'n'  # ń
        '\u00F3' = 'o'  # ó
        '\u015B' = 's'  # ś
        '\u017A' = 'z'  # ź
        '\u017C' = 'z'  # ż
        '\s' = '_'
    }
    foreach ($key in $polishReplacements.Keys) {
        $string = $string -replace $key, $polishReplacements[$key]
    }
    return $string
}


# wsczytywanie danoych do skryptu
if ($args[0] -eq '-h' -or $args[0] -eq '--help'){
    Write-Host "(help page)"
    Write-Host 'podstawowe uzycie:'
    Write-Host '$./meteo.sh "city_name"'
    Write-Host
    Write-Host 'pokazanie strony z pomoca:'
    Write-Host '$./meteo.sh -h    or    $./meteo.sh --help'
    Write-Host
    Write-Host 'pokazywanie komunikatow o aktualnym dzialaniu programu:'
    Write-Host '$./meteo.sh --debug "city_name"    or    $./meteo.sh --verbose "city_name"'
    exit 0
}


if ($args[0] -eq "--verbose" -or $args[0] -eq "--debug"){
    $debug=1
    $homeCity=$args[1]
}
elseif ($args[1] -eq "--verbose" -or $args[1] -eq "--debug") {
    $debug=1
    $homeCity=$args[0]
}
else {
    $homeCity=$args[0]
}

if (-not (Test-Path $userProfilePath"\.meteorc")){
    "$userProfilePath\.cache\meteo" | Out-File $userProfilePath"\.meteorc"
}
$cashePath = Get-Content $userProfilePath"\.meteorc"

if (-not (Test-Path -Path $cashePath)) {
    New-Item -ItemType Directory -Path $cashePath | Out-Null
}


if ((Test-Path "$cashePath\meteoTime.txt") -and (Test-Path "$cashePath\meteoCache.json")) {
    if ((Get-Content "$cashePath\meteoTime.txt") -eq (Get-Date -Format "yyyyMMddHH")){
        $meteoAPI = Get-Content "$cashePath\meteoCache.json" | ConvertFrom-Json
    }
    else{
        $meteoAPI = Invoke-RestMethod -Uri "https://danepubliczne.imgw.pl/api/data/synop" -Method Get
        $meteoAPI | ConvertTo-Json | Out-File "$cashePath\meteoCache.json"
        Get-Date -Format "yyyyMMddHH" | Out-File "$cashePath\meteoTime.txt"
    }
}
else{
    $meteoAPI = Invoke-RestMethod -Uri "https://danepubliczne.imgw.pl/api/data/synop" -Method Get
    $meteoAPI | ConvertTo-Json | Out-File "$cashePath\meteoCache.json"
    Get-Date -Format "yyyyMMddHH" | Out-File "$cashePath\meteoTime.txt"
}



$cityCashFilePath = "$cashePath\cityCash.txt"

if (Test-Path $cityCashFilePath) {
    $cityCash = Get-Content -Path $cityCashFilePath
}

function CacheContains($nazwaMiasta) {
    foreach ($line in $cityCash) {
        # Split the line using whitespace as the delimiter
        $parts = $line -split '\s+'

        if ($parts[0] -eq $nazwaMiasta){return 1}
    }
    return 0
}
function CityX($nazwaMiasta) {
    foreach ($line in $cityCash) {
        # Split the line using whitespace as the delimiter
        $parts = $line -split '\s+'

        if ($parts[0] -eq $nazwaMiasta){
            return [double]$parts[1]
        }
    }
}
function CityY($nazwaMiasta) {
    foreach ($line in $cityCash) {
        # Split the line using whitespace as the delimiter
        $parts = $line -split '\s+'

        if ($parts[0] -eq $nazwaMiasta){
            return [double]$parts[2]
        }
    }
}

function AddCity($nazwaMiasta, $x, $y) {
    $line = "$nazwaMiasta $x $y"
    $line | Out-File -FilePath $cityCashFilePath -Append -Encoding utf8
}

function WriteAll {
    foreach ($line in $cityCash) {
        # Split the line using whitespace as the delimiter
        $parts = $line -split '\s+'

        Write-Host $parts[0] [double]$parts[1] [double]$parts[2]
    }
}

for ($i = 0; $i -le $meteoAPI.Length; $i++){
    if ($i -eq $meteoAPI.Length){
        $cityName = $homeCity
    }
    else {
        $cityName = $meteoAPI[$i].stacja
    }
    $normalizedCityName = Normalize -string $cityName

    if(-not (CacheContains -nazwaMiasta $normalizedCityName)){
        if ($debug -eq 1){Write-Host "caching "$normalizedCityName}
        $cityAPI = Invoke-RestMethod -Uri "https://nominatim.openstreetmap.org/search?country=Poland&city='$normalizedCityName'&limit=1&format=geojson"# -Headers @{ "User-Agent" = "Mozilla/5.0" }
        AddCity -nazwaMiasta $normalizedCityName -x $cityAPI.features[0].geometry.coordinates[0] -y $cityAPI.features[0].geometry.coordinates[1]
        $cityCash = Get-Content -Path $cityCashFilePath
        Start-Sleep -Seconds 1
    }
    else{
        if ($debug -eq 1){Write-Host "already cached" $normalizedCityName}
    }
}

$normalizedHomeCity = Normalize -string $homeCity

$shortCity = $meteoAPI[0].stacja


for ($i = 1; $i -lt $meteoAPI.Length; $i++){
    
    $cityName = $meteoAPI[$i].stacja
    $normalizedCityName = Normalize -string $cityName

    $deltax = (CityX -nazwaMiasta $normalizedHomeCity) - (CityX -nazwaMiasta $normalizedCityName)
    $deltay = (CityY -nazwaMiasta $normalizedHomeCity) - (CityY -nazwaMiasta $normalizedCityName)
    $dist = $deltax*$deltax + $deltay*$deltay

    $normalizedShortCity = Normalize -string $shortCity

    $deltax = (CityX -nazwaMiasta $normalizedHomeCity) - (CityX -nazwaMiasta $normalizedShortCity)
    $deltay = (CityY -nazwaMiasta $normalizedHomeCity) - (CityY -nazwaMiasta $normalizedShortCity)

    $shortDist = $deltax*$deltax + $deltay*$deltay

    if ($debug -eq 1){Write-Host "comparing" $cityName "with" $shortCity}

    if($dist -lt $shortDist){
        $shortCity = $cityName
    }

}


for ($i = 0; $i -le $meteoAPI.Length; $i++){
    if($shortCity -eq $meteoAPI[$i].stacja){
        Write-Host $shortCity '['$meteoAPI[$i].id_stacji'] /'$meteoAPI[$i].data_pomiaru $meteoAPI[$i].godzina_pomiaru": 00"
        Write-Host "temperatura:" $meteoAPI[$i].temperatura "°C"
        Write-Host "predkosc wiatru:" $meteoAPI[$i].predkosc_wiatru "m/s"
        Write-Host "kierunek_wiatru:" $meteoAPI[$i].kierunek_wiatru "°"
        Write-Host "wilgotnosc wzgledna:" $meteoAPI[$i].wilgotnosc_wzgledna "%"
        Write-Host "sumaopadu:" $meteoAPI[$i].suma_opadu "mm"
        Write-Host "cisnienie:" $meteoAPI[$i].cisnienie "hPa"
        exit 0
    }
}

