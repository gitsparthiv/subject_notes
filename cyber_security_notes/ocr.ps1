Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' }

function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    return $netTask.Result
}

[Windows.Globalization.Language, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null

$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('en-US'))

function Ocr-Folder($folder, $outFile) {
    $files = Get-ChildItem -Path $folder -Filter *.png | Sort-Object { [int]($_.BaseName -replace '\D','') }
    $allText = ""
    foreach ($file in $files) {
        $storageFile = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($file.FullName)) ([Windows.Storage.StorageFile])
        $streamOpen = Await ($storageFile.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
        $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($streamOpen)) ([Windows.Graphics.Imaging.BitmapDecoder])
        $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
        $ocrResult = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
        $allText += "`n`n=== " + $file.BaseName + " ===`n" + $ocrResult.Text
        $streamOpen.Dispose()
    }
    Set-Content -Path $outFile -Value $allText -Encoding UTF8
    Write-Host "Done $outFile ($($files.Count) pages)"
}

Ocr-Folder 'extracted_images/unit2' 'unit2_ocr.txt'
Ocr-Folder 'extracted_images/unit3' 'unit3_ocr.txt'
Ocr-Folder 'extracted_images/unit4' 'unit4_ocr.txt'

