#RStudio Connect Application Update POSH
#EggsToastBacon 10/28/2020

#csv file should contain 3 columns; 
#1. host: url of the RStudio connect server "https://connect.company.com", 
#3. key: api key of the server to authenticate

#Use the config file to specify, config file stays in the same directory as the script.
#1. CSV File location
#2. CURL location (use the latest CURL binaries)
#3. Location of the application update tar.gz file
#4. App name

$config = get-content .\config.txt
$nodes = Invoke-Expression $config[1]
$curl_loc = Invoke-Expression $config[3]
$package_loc = Invoke-Expression $config[5]
$appname = Invoke-Expression $config[7]
cls
$go = read-host "This will install for the first time: $appname with bundle: $package_loc, press ENTER to continue"

clear-variable errors -ErrorAction SilentlyContinue

$appName = read-host "Enter Name for the new Application"
$appTitle = $appName

$namejson = @"
{"name":"$appName","title":"$appTitle"}
"@

$namejson = $namejson| ConvertTo-Json


foreach($node in $nodes){
$hostname = $node.host
$key = $node.key

write-host "Registering App with $hostname" -ForegroundColor Cyan


$stage = cmd.exe /C $curl_loc --silent --show-error -L --max-redirs 0 --fail -X POST -H "Authorization: Key $key" -d $namejson "$hostname/__api__/v1/experimental/content"

$data = $stage | convertFrom-JSON
$guid = $data.guid

write-host "Appending data to CSV file.."

 [pscustomobject]@{
        host = $hostname
        guid = $data.guid
        key = $key
    } | export-csv ./exported_deployment.csv -append

write-host "Appending data to CSV file"

$bundle = cmd.exe /C $curl_loc --silent --show-error -L --max-redirs 0 --fail -X POST -H "Authorization: Key $key" --data-binary $package_loc "$hostname/__api__/v1/experimental/content/$guid/upload"

$bundle = $bundle | convertFrom-JSON
$id = $bundle.bundle_id

write-host "Bundle ID $id" -ForegroundColor Cyan

$bundlejson = @"
{"BUNDLE_ID":"$id"}
"@

$bundlejson = $bundlejson | ConvertTo-Json

$task = cmd.exe /C $curl_loc --silent --max-redirs 10 -X POST -H "Authorization: Key $key" -H "Accept: application/json" -d $bundlejson -L "$hostname/__api__/v1/experimental/content/$guid/deploy"

$task = $task | ConvertFrom-JSON
$task = $task.task_id

write-host "Task $task" -ForegroundColor Cyan
$x = 0
do{$result = cmd.exe /C $curl_loc --silent --show-error -L --max-redirs 0 -H "Authorization: Key $key" ("$hostname/__api__/v1/experimental/tasks/" + $task + "?wait=1")
$result = $result | convertFrom-JSON
start-sleep 5
$x = $x + 5
write-host "$x secondselapsed deploying on $hostname" -ForegroundColor Yellow

if ($x -gt 300){
$errors += "$hostname : Didn't get the finished result after 5 minutes : $result"
break
}}
while($result.finished -notlike "*True*")
if ($result.error){
$errors += "$hostname : Error Detected  : $result"
}

write-host "Done on $hostname.."
}

if($errors){write-host "Errors Detected"
$errors
}
$finished = read-host "Finished.. press any key to close."
