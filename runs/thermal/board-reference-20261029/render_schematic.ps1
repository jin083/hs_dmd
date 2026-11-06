Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Pdf.PdfPageRenderOptions, Windows.Data.Pdf, ContentType=WindowsRuntime] | Out-Null
$taskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
function Await-Result($operation, [Type]$resultType) {
    $task = $taskMethod.MakeGenericMethod($resultType).Invoke($null, @($operation))
    $task.Wait()
    return $task.Result
}
$pdfPath = Join-Path $PSScriptRoot 'DLPLCRC410EVM_RevC_SCH.pdf'
$storageFile = Await-Result ([Windows.Storage.StorageFile]::GetFileFromPathAsync($pdfPath)) ([Windows.Storage.StorageFile])
$document = Await-Result ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($storageFile)) ([Windows.Data.Pdf.PdfDocument])
foreach ($pageIndex in @(6, 10)) {
    $page = $document.GetPage($pageIndex)
    $stream = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
    $options = New-Object Windows.Data.Pdf.PdfPageRenderOptions
    $options.DestinationWidth = 3400
    $renderTask = [System.WindowsRuntimeSystemExtensions]::AsTask($page.RenderToStreamAsync($stream, $options))
    $renderTask.Wait()
    $stream.Seek(0)
    $readStream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
    $targetPath = Join-Path $PSScriptRoot ('schematic-page-' + ($pageIndex + 1) + '.png')
    $targetStream = [System.IO.File]::Create($targetPath)
    $readStream.CopyTo($targetStream)
    $targetStream.Dispose()
    $readStream.Dispose()
    $page.Dispose()
    Write-Output $targetPath
}
