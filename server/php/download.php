<?php
$zipfile = $_GET['zip'];
$file = $_GET['file'];
if(!empty($zipfile)){
    // Testa se arquivo existe e se ZIP.
    if(file_exists($zipfile) && is_file($zipfile))
    {
        $zip = new ZipArchive;
        $res = $zip->open( $zipfile );
        if( $res=== TRUE )
        {
            $path_parts = pathinfo($zipfile);
	    if(!file_exists( $path_parts["dirname"] . DIRECTORY_SEPARATOR . "tmp" ) )
	    {
              mkdir( $path_parts["dirname"] . DIRECTORY_SEPARATOR . "tmp" );
            }
            $fullfile = $path_parts["dirname"] . DIRECTORY_SEPARATOR . "tmp" . DIRECTORY_SEPARATOR . $file;
	    if(file_exists( $fullfile ) && is_file( $fullfile))
	    {
              unlink($fullfile);
            }
	// Descompacta arquivo na pasta tmp.
            $zip->extractTo( $path_parts["dirname"] . DIRECTORY_SEPARATOR . "tmp" . DIRECTORY_SEPARATOR ,$file);
            $zip->close();
	    if(file_exists( $fullfile ) && is_file( $fullfile))
	    {
		$fsize = filesize($fullfile);
		$path_parts = pathinfo($fullfile);
		$ext = strtolower($path_parts["extension"]);
		// determina o comportamento para extensão PDF ou outras.
		switch ($ext) {
		case "pdf":
		    header("Content-type: application/pdf");
		    header("Content-Disposition: inline; filename=\"".$path_parts["basename"]."\"");     //Força download
		    break;
	        default;
		    header("Content-type: application/octet-stream");
		    header("Content-Disposition: filename=\"".$path_parts["basename"]."\"");
		}
		header("Content-length: $fsize");
		header("Cache-control: private");
		ob_end_flush();
		// disponibiliza finalmente o arquivo.
		readfile($fullfile);
		    if(file_exists( $fullfile ) && is_file( $fullfile))
		    {
	              unlink($fullfile);
	            }
	    }
	    else
	    {
              echo 'Falha ao Extrair:' . $file;
	    }
        }
        else
        {
          echo 'Falha ao Abrir:' . $zipfile;
        }
    }
    else
    {
      echo 'Arquivo Nao Existe:'. $zipfile;
    }
 }
?>
