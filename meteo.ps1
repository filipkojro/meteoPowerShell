
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


Write-Host $userProfilePath"\.cache\meteo"
$cacheFilePath = Join-Path $userProfilePath ".meteorc"

if (-not (Test-Path $userProfilePath"\.meteorc")) {

    Write-Host "No cache file"

    # Create the cache file with default values
    $cacheContent = @{
        cashpath = (Join-Path $userProfilePath ".cache\meteo\")
    } | ConvertTo-Json

    $cacheContent | Set-Content -Path $cacheFilePath

    # Create the cache directory
    $cacheDirectory = Join-Path $userProfilePath ".cache\meteo"
    if (-not (Test-Path -Path $cacheDirectory)) {
        New-Item -ItemType Directory -Path $cacheDirectory | Out-Null
    }
}

$meteoAPI = Invoke-RestMethod -Uri "https://danepubliczne.imgw.pl/api/data/synop" -Method Get

if (-not (Test-Path ".\cityCash.json")){
    Write-Host "pierwsze uruchomienie potrwa ponad minute z powodu ograniczen nalozonych przez https://nominatim.org/ prosze o cierpliwosc :)"
    "{}" | Out-File -FilePath ".\cityCash.json"
}
$cityCash = Get-Content ".\cityCash.json" | ConvertFrom-Json

for ($i = 0; $i -le $meteoAPI.Length; $i++){
    if ($i -eq $meteoAPI.Length){
        $cityName = $homeCity
    }
    else {
        $cityName = $meteoAPI[$i].stacja
    }
    $normalizedCityName = Normalize -string $cityName

    if (-not ($cityCash -contains $normalizedCityName)){
        $cityData = Invoke-RestMethod -Uri "https://nominatim.openstreetmap.org/search?country=Poland&city='$normalizedCityName'&limit=1&format=geojson"# -Headers @{ "User-Agent" = "Mozilla/5.0" }
        #$cityCash[$normalizedCityName] = "$cityData.features[0].geometry.coordinates[0]"
        $cityCash | Add-Member -MemberType NoteProperty -Name $normalizedCityName -Value @{
            "x" = $cityData.features[0].geometry.coordinates[0]
            "y" = $cityData.features[0].geometry.coordinates[0]
        }
        $cityCash | ConvertTo-Json | Out-File ".\cityCash.json"
    }
    Write-Host kesz $cityCash.$normalizedCityName
    
    #$cityData = Invoke-RestMethod -Uri "https://nominatim.openstreetmap.org/search?country=Poland&city='$normalizedCityName'&limit=1&format=geojson"# -Headers @{ "User-Agent" = "Mozilla/5.0" }
    #Write-Host $normalizedCityName
    #Write-Host $cityData.features[0].geometry.coordinates[0]



    #Write-Host $cityCash["Bydgoszcz"]

    Start-Sleep -Seconds 1
}