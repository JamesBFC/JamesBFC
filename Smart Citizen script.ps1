# --- Configuration ---
# Specify the URL of the file you want to download
$url = "https://github.com/JamesBFC/JamesBFC/raw/refs/heads/main/SmartCitizen.SmartInput.exe"

# Specify the full path where you want to save and run the file
$destinationPath = "C:\"
# --- End of Configuration ---

# 1. Download the file
try {
    Write-Host "Downloading file from $url..."
    Invoke-WebRequest -Uri $url -OutFile $destinationPath
    Write-Host "File downloaded successfully to $destinationPath"
}
catch {
    Write-Host "Error downloading file: $_"
    # Stop the script if the download fails
    return
}

# 2. Run the file
try {
    Write-Host "Running file: $destinationPath..."
    Start-Process -FilePath $destinationPath
    Write-Host "Process started."
}
catch {
    Write-Host "Error running file: $_"

}
