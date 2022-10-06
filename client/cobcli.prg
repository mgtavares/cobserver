
function FaturaEmailProtegePDF( aFiles, cSenha, cMensErro )
   local lOk := .T.
   local nI, cTemp
   local cNomePDFUnico := "boleto"
   local cArqErr

   // Abastece cTemp com linha de comando com todos os arquivos PDF encontrados.
   cTemp := ''
   nI := 1
   while nI <= len( aFiles )
      if lower( ArqObtemExtensao( aFiles[ nI ] ) ) == "pdf"
         if empty( cTemp )
            cTemp := "qpdf --encrypt " + cSenha + " " + cSenha + ' 128 --modify=none -- --empty --pages'
         endif
         cTemp += ( ' "' + aFiles[ nI ] + '"' )
         aFiles := adel( aFiles, nI )
         aFiles := asize( aFiles, len( aFiles ) - 1 )
         loop
      endif
      nI ++
   enddo
   // Arquivos PDF removidos da matriz de anexos.

   if ! empty( cTemp )
      // Se há PDF para criptografar, acrescenta arquivos de destino a serem criados na pasta termporária.

      // Acrescenta o arquivo único criptografado a lista de arquivos enviar.
      aadd( aFiles, Retpathtemp() + nomearqtemp( cNomePDFUnico ) + ".pdf" )
      // Define arquivo para retorno de erro.
      cArqErr := Retpathtemp() + nomearqtemp( "qpdf" ) + ".err"
      // Adiciona Arquivo único e arquivo de erro para a linha de comando.
      cTemp += ( ' -- "' + atail( aFiles ) + '" 2> ' + cArqErr )

      // Executa programa externo para unificar e criptografar PDF.
      __run( cTemp )
      k_wait( 1 )

      IF file( cArqErr )
         // Se erro no processamento
         cMensErro := "Erro: PDF Mal Formado ! ;" + atail( aFiles ) + " ; " + memoread( cArqErr )
         ferase( cArqErr )
         lOk := .F.
      endif
   endif

   return( lOk )

static function EnviaArquivosCobServer( aFiles, cCNPJ, aFatura, cMensErro )
   local lOk := .F.
   local cUrlSSH   := CobServerSSHUrl()
   local cChaveSSH := CobServerKeyFile()
   local cPathSSH  := CobServerPath()
   local cPortaSSH
   local cLogSSH   := RetPathArqTemp( "scpcob.log" )
   local cFileZip
   local cRun
   local nI

   cPathSSH  := CobServerPath() + "/" + cCNPJ

   // Extrai Porta de cURLSSH no formato usuário@servidor:porta
   if ( nI := rat( ":", cUrlSSH ) ) > 0 .and. IsNumero( subst( cUrlSSH, nI + 1 ), .F. )
      cPortaSSH := subst( cUrlSSH, nI + 1 )
      cUrlSSH := left( cUrlSSH, nI - 1 )

      // Se porta OK, Obtem nome do pacote conforme regras do servidor remoto
      if ! empty( cFileZip := CobServerCalcNomeZip( aFatura ) )
         // Caso arquivo destino exista, exclui.
         if file( cFileZip )
            ferase( cFileZip )
            k_wait( .1 )
         endif
         // Compacta arquivos para Envio.
         if hb_zipFile( cFileZip, aFiles,,,,, .F., .F. ) // No Path / No Drive ( Windows ).

            // Define linha de comando
            cRun := "scp -q -P " + cPortaSSH + ;
                    " -i " + cChaveSSH + ;
                    " -o ConnectTimeout=15 " + ;
                    " -o StrictHostKeyChecking=no " + ;
                    " -o UserKnownHostsFile=/dev/null " + ;
                    cFileZip + " " + ;
                    cUrlSSH + ":" + cPathSSH + "/." + ;
                    " 2> /dev/null;echo $? > " + cLogSSH
            // Executa comando scp
            __run( cRun )
            // Analisa retorno
            if file( cLogSSH ) .and. left( hb_memoread( cLogSSH ), 1 ) == '0'
               // Arquivo Enviado Ok
               lOk := .T.
            else
               cMensErro := "Falha Envio Arquivo:" + cRun
            endif
         else
            cMensErro := "Falha ao compactar arquivos!"
         endif
      else
         cMensErro :=  "Falha ao calcular Nome Arquivo"
      endif
   else
      cMensErro := "SCE_COBSERVER_SSH com porta invalida.;" + cUrlSSH
   endif
   return( lOk )

static function CobServerCalcNomeZip( aFatura )
   local cFileZip := ''
   LOCAL nI
   Local dValidade

   // Obtem Ultimo Vencimento, codigo da cobranca ( Banco/Conta ) e Boleto para compor nome do Arquivo
   nI := FaturaRetornaIndiceUltimoVenc( aFatura )
   IF nI > 0
      // Se Há cobrancas validas
      dValidade := aFatura[ nI ][ "DtVenc" ] + 30 // Validade máxima de 30 dias
      cFileZip  := RetPathTemp() + "cob" + "_" + dtos( dValidade ) + "_" + ;
                   aFatura[ nI ][ "CodCobranca" ] + "_" + ;
                   aFatura[ nI ][ "NumBoleto" ] + ".zip"
   endif
   return( cFileZip )


static function FaturaRetornaIndiceUltimoVenc( aFatura )
   local nI
   local nRet := 0
   Local dUltVenc, cUltBoleto

   for nI := 1 to len( aFatura )
      if empty( dUltVenc ) .or. ;
         dUltVenc < aFatura[ nI ][ "DtVenc" ] .or. ;
         ( dUltVenc == aFatura[ nI ][ "DtVenc" ] .and. ;
           val( cUltBoleto ) < val( aFatura[ nI ][ "NumBoleto" ] ) )

         // Escolhe maior vencimento/boleto
         cUltBoleto := alltrim( aFatura[ nI ][ "NumBoleto" ] )
         dUltVenc   := aFatura[ nI ][ "DtVenc" ]
         nRet := nI

      endif
   next

   return( nRet )

function CobServerHiperlink( cCNPJEmpresa, cCNPJCPFCliente, cNomeCliente , aFatura )
   local cLink := ''
   local cToken
   local h := hash()
   local nI
   local cCodBlo, dUltVenc, dValidade, cUltBoleto

   nI := FaturaRetornaIndiceUltimoVenc( aFatura )

   IF nI > 0
      // Se faturas válidas, preenche estrutura hash a ser transformada em JSON
      h[ "CNPJEmpresa" ] := cCNPJEmpresa
      // Armazena apenas o nome do arquivo ZIP.
      h[ "ArqZIP"     ] := NomeArqExtraiNome( CobServerCalcNomeZip( aFatura ) )
      h[ "CNPJCPF"     ] := cCNPJCPFCliente
      h[ "Cliente"    ] := cNomeCliente
      h[ "CodCobranca"    ] := aFatura[ nI ][ "CodCobranca" ]
      h[ "dPostagem"  ] := aFatura[ nI ][ "DtPostagem" ]
      h[ "dUltVenc"   ] := aFatura[ nI ][ "DtVenc" ]
      h[ "dValidade"  ] := aFatura[ nI ][ "DtVenc" ] + 30 // Validade maxima de 30 dias
      h[ "Boletos"    ] := { } // matriz vazia

// Preenche matriz de boletos com Numeros dos Boletos
      for nI := 1 to len( aFatura )
         if ascan( h[ "Boletos"    ], alltrim( aFatura[ nI ][ "NumBoleto" ] ) ) == 0
            aadd( h[ "Boletos"    ], alltrim( aFatura[ nI ][ "NumBoleto" ] ) )
         endif
      next
      // Obtem string em JSON
      cToken      := hb_jsonencode( h )
      // Codifica e converte para URL ( Base64 )
      cToken := k_StrToUrl( k_CodificaToken( cToken ) )

      // Monta o Link com conteúdo variável COBSERVER_HTTP, nome do WebService ( cobaceite ) e o
      // Token como parâmetro  GET.
      cLink := CobServerHttpUrl() + "/cobaceite" + "?" + cToken

   endif
   return( cLink )

function CobServerConsulta( cCNPJEmpresa )
   local cUrl   := CobServerHTTPUrl() + "/cgi-bin/cobconsulta?"
   local cToken
   local cRet
   local xRet
   local oHTTP
   local nI
   local lOk
   local cMensErro := ''

   // Passa o CNPJ para funcao remota em forma de token codificado.
   cToken := cCNPJEmpresa
   cToken := k_StrToUrl( k_CodificaToken( cToken ) )

   // Inicia Objeto HTTP
   oHTTP := TIPClientHTTP():New( cToken )
   oHTTP:nConnTimeout := 10000    // Dez Segundos
   // Inicia comunicacao
   IF ( oHTTP:Open() )
      // Obtem retorno do Web Service
      cRet := oHTTP:ReadAll()
      oHTTP:Close()

      // cRet contém string de retorno, testa se estrutura JSON válida
      if ( hb_jsondecode( cRet, @xRet ) > 0 ) .AND. ;
         ( valtype( xRet ) == "H" .or. valtype( xRet ) == "A" )
         // Se retornou Matriz ou Hash
         if valtype( xRet ) == "H" .and. hb_hHasKey( xRet, "Erro" )
            // Se Erro
            cMensErro := "CobServerConsulta:Erro Consulta:" + xRet[ "Erro" ]
         elseif valtype( xRet ) == "A"
            // Se Matriz
            if empty( xRet )
               // Se Matriz Vazia
               cMensErro := "CobServerConsulta:OK.Nada a atualizar!"
            else
               // Varre matriz testanto a estrutura JSON retornada
               nI := 1
               lOk := .T.
               while lOk .and. nI <= len( xRet )
                  if ! ( hb_hHasKey( ( xRet[ nI ] ), "CodCobranca" ) .and. ;
                         ! strempty( ( xRet[ nI ] )[ "CodCobranca" ] ) .and. ;
                         hb_hHasKey( ( xRet[ nI ] ), "DtAceite" ) .and. ;
                         ! strempty( ( xRet[ nI ] )[ "DtAceite" ] ) .and. ;
                         hb_hHasKey( ( xRet[ nI ] ), "HrAceite" ) .and. ;
                         ! strempty( ( xRet[ nI ] )[ "HrAceite" ] ) .and. ;
                         hb_hHasKey( ( xRet[ nI ] ), "Boletos" ) .and. ;
                         ! empty( ( xRet[ nI ] )[ "Boletos" ] ) )
                     lOk := .F.
                  endif
                  nI ++
               enddo
               if ! lOk
                  // Se Nao retornou Matriz com estrutura JSON correta
                  cMensErro := "CobServerConsulta:Retorno Invalido:" + cRet
               endif
            endif
         endif
      elseif valtype( cRet ) == "C"
         // Se retornou string simples
         cMensErro := "CobServerConsulta:Retorno Invalido:" + cRet
      else
         cMensErro := "CobServerConsulta:Retorno Invalido:" + cToken
      endif
   else
      cMensErro := "CobServerConsulta:Falha ao abrir:" + cToken
   endif

   return( IF( lOk, xRet, cMensErro )  )

function CobServerEnviaBaixa( cCNPJEmpresa, cCodCobranca, aBoletos )
   local cUrl   := CobServerHTTPUrl() + "/cgi-bin/cobaltera?"
   local h := hash()
   local xRet
   local cRet
   local cToken
   local oHTTP
   local nI
   local cErro

   // Preenche Estrutura para envio ao webservice
   h[ "CNPJEmpresa" ] := cCNPJEmpresa
   h[ "CodBloq"     ] := cCodCobranca
   h[ "dBaixa"      ] := dataatual()
   h[ "hrBaixa"     ] := horaatual()
   h[ "Boletos"     ] := { }
   // Transfere itens matriz de boletos para a estrutura.
   aeval( aBoletos, { | a | aadd( h[ "Boletos"     ], a ) } )

   // Codifica a estrutura em formato JSON e para “token”
   cToken := hb_jsonencode( h )
   cToken := k_StrToUrl( k_CodificaToken( cToken ) )

   // Aciona servico CobAltera.
   oHTTP := TIPClientHTTP():New( cToken )
   oHTTP:nConnTimeout := 10000    // Dez Segundos
   IF ( oHTTP:Open() )
      // Se enviou requisicao, recebe o retorno
      cRet := oHTTP:ReadAll()
      oHTTP:Close()

      if ( hb_jsondecode( cRet, @xRet ) > 0 ) .AND. ;
         valtype( xRet ) == "H" .and. ;
         ! empty( xRet )
         // Se recebeu estrutura JSON

         if hb_hHasKey( xRet, "Erro" )
            // Se Erro, retorna mensagem
            cErro := "cobaltera Erro :" + xRet[ "Erro" ]
         elseif  hb_hHasKey( xRet, "OK!" )
            cErro := '' // Sem mensagem se operacao OK
         ELSE
            cErro := "cobaltera Erro : Nao retornado"
         endif
      elseif valtype( cRet ) == "C"
         cErro := "cobaltera Retorno Invalido:" + cRet
      else
         cErro := "cobaltera Retorno Invalido:" + cToken
      endif
   else
      cErro := "cobaltera:Falha ao abrir:" + cToken
   endif

   return( cErro )

// Obtem variavel
function CobServerSSHUrl()
   local   c := lower( alltrim( getenv( "SCE_COBSERVER_SSH" ) ) )
   RETURN( c )

function CobServerPath()
   local   c := lower( alltrim( getenv( "SCE_COBSERVER_PATH" ) ) )
   RETURN( c )

function CobServerKeyFile()
   local   c := lower( alltrim( getenv( "SCE_COBSERVER_SSHKEYFILE" ) ) )
   local   cDefault := "./private.rsa"
   local cKey

   RETURN( if( strempty( c ), cDefault, c ) )

// Exemplo: http://h1.linhaverde.info:8800/cgi-bin
function CobServerHttpUrl()
   local   c := lower( alltrim( getenv( "SCE_COBSERVER_HTTP" ) ) )
   RETURN( c )


// Funcoes Diversas

// Obtem o caminho para pasta temporaria do sistema operacional
function RetPathTemp()
   local cPath

   #ifdef __PLATFORM__LINUX
      cPath := '/tmp/'
   #else
      cPath := if( strempty( GETENV( "TEMP" ) ), '.', alltrim( GETENV( "TEMP" ) ) ) + '\'
   #endif

   return( cPath )

// Gera nome unico a partir de um nome base de arquivo
FUNCTION NomeArqTemp( cArq )
   local nI
   local cExt

   IF cArq == NIL ;   cArq := '0' ;  endif
   if ( nI := at( '.', cArq ) ) > 0 // Se Tem Extens�o, preserva
      cExt := subst( cArq, nI )
      cArq := left( cArq, nI - 1 )
   endif
   cArq += alltrim( str( int( seconds() * 1000 ) ) )
   hb_randomSeed()
   cArq+=padl( int(hb_random( 999999 )),6,'0' )

   if ! empty( cExt )
      cArq += cExt
   endif
   RETURN( cArq )

// Gera Nome completo ( com path ) para arquivo temporario.
function RetPathArqTemp( cArq )
local cRet
   cRet := RetPathTemp() + NomeArqTemp( cArq )

   return( cRet )

// Extrai a extensao de um nome de arquivo.
function ArqObtemExtensao( cNome )
   local nI
   local cRet:=''

   cNome:=alltrim( cNome )
   nI := rat( '.', cNome )

   if nI > 0
      cRet := subst( cNome, nI + 1 )
   endif
   return( cRet )

// Extrai apenas nome do arquivo
function NomeArqExtraiNome( cPathNome )
   local nI
   local cNome

   if ( nI := rat( HB_OSPathSeparator(), cPathNome ) ) > 0
      cNome := subst( cPathNome, nI + 1 )
   else
      cNome := cPathNome
   endif

   return( cNome )

// Substitui simbolos invalidos para link URL
function k_StrToUrl( s )

   s := strtran( s, '+','-'  )
   s := strtran( s, '/','_'  )
   s := strtran( s, '=',','  )

   return( s )

// restaura simbolos invalidos para link URL
function k_UrlToStr( s )

   s := strtran( s, '-', '+' )
   s := strtran( s, '_', '/' )
   s := strtran( s, ',', '=' )

   return( s )

// Codifica String Token
function k_CodificaToken( cToken )

   cToken := hb_base64Encode( cToken )
   cToken := k_reverteSTR( cToken )
   cToken := hb_base64Encode( cToken )

   return( cToken )

// Decodifica String Token

function k_DeCodificaToken( cToken )
   cToken := hb_base64decode( cToken )
   cToken := k_reverteSTR( cToken )
   cToken := hb_base64decode( cToken )
   return( cToken )

// Inverte uma string
function k_reverteSTR( s )
   local r := ''
   local nI

   while len( s ) > 0
      r += right( s, 1 )
      s := left( s, len( s ) - 1 )
   enddo

   return( r )

// Testa se string realmente vazia.
function StrEmpty( cStr )
   return( cStr == NIL .or. empty( alltrim( cStr ) ) )

// Testa se string possui um numero V�lido
function IsNumero( cTmp, lConsideraVazioComoNumeroValido )
   local lNumero := .T.
   local nI
   local cChar

   DEFAULT lConsideraVazioComoNumeroValido TO .T.

   if ! lConsideraVazioComoNumeroValido .and. strempty( cTmp )
      lNumero := .F.
   else
      cTmp := alltrim( cTmp )
      for nI := 1 to len( cTmp )
         cChar := subst( cTmp, nI, 1 )
         if ! cChar $ "0123456789,."
            lNumero := .F.
         endif
      next
   endif
   return( lNumero )
