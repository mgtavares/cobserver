// Define pagina de codigo e internacionalizacao
#define __CP_HOST__ "PT850"
#define __CP_TERM__ "PTISO"

// Define pasta raiz no servidor para o projeto.
#define pDirRaiz "/data/cobserver"

// Define caminho para script PHP
#define pURLScriptPHP   "http://h1.linhaverde.info/php/download.php?zip={ZIP}&file={FILE}"


// Funcao de Entrada ( MAIN )
function main()
   local aParams := hb_aparams()
   local cToken
   local h := hash()
   local cFileZip
   local cTemp, nLen, nI

// Define pagina de codigo
   HB_CDPSELECT( __CP_HOST__ )
   HB_SETTERMCP( __CP_TERM__, __CP_HOST__, .T. )

// Define padrao banco de dados DBMS Foxpro
   RDDSETDEFAULT ( "BMDBFCDX" )


   if getenv( "REQUEST_METHOD" ) == "GET"
      // Se acesso por GET
      // Testa se paramento informado
      if empty( aParams )
         SendErro(  "GET Sem Parametros Informados" )
      elseif len( aParams ) != 1
         SendErro( "GET Paramentos Invalidos" )
      else

         if DecodificaToken( aParams[ 1 ], @h )
            // Se Token autenticado

            // Testa se arquivo alvo esta no servidor.
            if file( cFileZip := pDirRaiz + "/" + h[ "CNPJEmpresa" ] + "/" + h[ "ArqZIP" ] )

               // Solicita login/senha ao usuario.
               SendLogin( h[ "CNPJEmpresa" ], h[ "CNPJCPF" ], h[ "Cliente" ] )

            else
               SendErro( "Arquivo nao mais disponivel! Solicite nova cobranca!<br>" + cFileZip, h[ "CNPJEmpresa" ] )
            endif
         else
            SendErro( "GET Token Invalido" )
         endif

      endif
   elseif getenv( "REQUEST_METHOD" ) == "POST"      // Acionado quando usuario coloca a senha
      // Se acesso por POST
      if DecodificaToken( aParams[ 1 ], @h )
         // Se Token autenticado, possui todas as informacoes de cobranca

         // Procura o parametro 'password=' e a senha informada pelo usuario.
         nLen := val( hb_getenv( "CONTENT_LENGTH" ) )
         cTemp := Space( nLen )
         FRead( hb_GetStdIn(), @cTemp, nLen )
         if left( cTemp, 9 ) == 'password='
            if ( nI := at( "&", cTemp ) ) > 0
               cTemp := subst( cTemp, 10, nI - 10 )
            endif
            if valtype( h ) == "H" .and. hb_hHasKey( h, "CNPJCPF" )
               if IsNumero( cTemp ) .and. cTemp == left( h[ "CNPJCPF" ] , 5 )
                  // Se parametro existe e password correta.

                  LiberaDownload( h )

               else
                  SendErro( "Senha Invalida!", h[ "CNPJEmpresa" ]  )
               endif
            else
               SendErro( "CNPJ/CPF Invalido!", h[ "CNPJEmpresa" ] )
            endif
         else
            // Se parametros invalidos, informa para depurar erro.
            SendErro( "CONTENT_TYPE:" + hb_getenv( "CONTENT_TYPE" ) + "<br>" + ;
                      "CONTENT_LENGTH:" + hb_getenv( "CONTENT_LENGTH" ) + "<br>" + ;
                      "GETSTDIN:" + cTemp + "<br>" )
         endif
      endif
   endif

   return( NIL )

// Funcao de registro do Aceite e disponibilizar a pagina de download ao cliente.
static function LiberaDownload( h )
   local aFiles
   local cFileZip

   // Testa se arquivo disponível no servidor
   if file( cFileZip := pDirRaiz + "/" + h[ "CNPJEmpresa" ] + "/" + h[ "ArqZIP" ] )
      // Obtem lista de arquivos que pertencem ao arquivo compactado.
      if ! empty( aFiles := hb_GetFilesInZip( cFileZip, .F. ) )
         // Registra Acesso do Cliente ( Aceite ).
         if IncluiAceite( h )
            // Disponibiliza ao usuario, pagina HTML para a escolha e download dos arquivos.
            SendDownload( h[ "CNPJEmpresa" ], h[ "CGCCPF" ], h[ "Cliente" ], cFileZip, aFiles )
         Else
            // Avisa ao cliente a impossibilidade tecnica de registrar o acesso.
            SendErro( "Falha ao Registrar aceite!<br>Solicite nova cobranca!" + cFileZip , h[ "CNPJEmpresa" ] )
         endif
      else
         // Avisa ao cliente a ausencia dos arquivos.
         SendErro( "Arquivo Vazio! Solicite nova cobranca!<br>" + cFileZip , h[ "CNPJEmpresa" ] )
      endif
   else
      SendErro( "Arquivo nao mais disponivel! Solicite nova cobranca!<br>" + cFileZip, h[ "CNPJEmpresa" ] )
   endif

   return( NIL )


// Funcao auxiliar que valida, decodifica e extrai as informacoes de cobranca.
static function DecodificaToken( cToken, h )
   local lOk

   cToken := k_DeCodificaToken( k_UrlToStr( cToken ) )

   lOk := ! empty( cToken ) .and. ;
          hb_jsondecode( cToken, @h ) > 0 .and. ;
          hb_hHasKey( h, "Boletos" ) .and. ;
          valtype( h[ "Boletos" ] ) == "A" .and. ;
          len( h[ "Boletos" ] ) > 0 .and. ;
          hb_hHasKey( h, "CNPJEmpresa" ) .and. valtype( h[ "CNPJEmpresa" ] ) == "C" .and. ! strempty( h[ "CNPJEmpresa" ] ) .and. ;
          hb_hHasKey( h, "ArqZIP" ) .and. valtype( h[ "ArqZIP" ] ) == "C" .and. ! strempty( h[ "ArqZIP" ] ) .and. ;
          hb_hHasKey( h, "CNPJCPF" ) .and. valtype( h[ "CNPJCPF" ] ) == "C" .and. ! strempty( h[ "CNPJCPF" ] ) .and. ;
          hb_hHasKey( h, "Cliente" ) .and. valtype( h[ "Cliente" ] ) == "C" .and. ! strempty( h[ "Cliente" ] ) .and. ;
          hb_hHasKey( h, "CodBloq" ) .and. valtype( h[ "CodCobranca" ] ) == "C" .and. ! strempty( h[ "CodCobranca" ] ) .and. ;
          hb_hHasKey( h, "DtPostagem" ) .and. valtype( h[ "DtPostagem" ] ) == "C" .and. ! strempty( h[ "DtPostagem" ] ) .and. ;
          hb_hHasKey( h, "DtUltVenc" ) .and. valtype( h[ "DtUltVenc" ] ) == "C" .and. ! strempty( h[ "DtUltVenc" ] ) .and. ;
          hb_hHasKey( h, "DtValidade" ) .and. valtype( h[ "DtValidade" ] ) == "C" .and. ! strempty( h[ "DtValidade" ] )

   return( lOk )

// Funcao auxiliar para gerar pagina HTML a partir do arquivo modelo 'coberro.htm'.
static function SendErro( cErro, cCNPJ )
   local cRaiz := pDirRaiz
   local cPath
   local cHtm
   local nI

   if empty( cCNPJ ) .or. ;
      ! file( cRaiz + hb_ospathseparator() + cCNPJ + hb_ospathseparator() + "htm" + hb_ospathseparator() + "coberro.htm" )
      // Se erro nao informou o CNPJ da empresa, utiliza HTML basico para exibir o erro.

      outstd( "Content-type: text/html; charset=iso-8859-1" + hb_OSNewLine() + hb_OSNewLine() ) // Obrigatorio 2 avancos de linha
      outstd( '<html><meta charset="iso-8859-1"/><body><div>' )
      outstd( "<p>" + cErro + "</p><br>" )
      outstd( "</div></body></html>" + hb_OSNewLine() )

   else
      // Se CNPJ informado e ha o arquivo de modelo para a empresa, o utiliza.
      cPath := cRaiz + hb_ospathseparator() + cCNPJ + hb_ospathseparator() + "htm"
      cHtm := memoread( cPath + hb_ospathseparator() + "coberro.htm" )

      // Substitui a string '{ERRO}' no modelo, pela conteudo da variavel cErro.
      cHtm := strtran( cHtm, "{ERRO}", cErro )

      // Disponibiliza pagina HTML informativa ao usuario.
      outstd( "Content-type: text/html" + hb_OSNewLine() + hb_OSNewLine() ) // Obrigatorio 2 avancos de linha
      for nI := 1 to mlcount( cHtm )
         outstd( memoline( cHtm,, nI ) )
      next
   endif

   return( NIL )

// Funcao auxiliar para disponibilizar pagina HTML de 'bem-vindo' ao usuário.
static function SendLogin( cCNPJ, cCNPJCPFCliente, cCliente )
   local cRaiz := pDirRaiz
   local cPath := cRaiz + hb_ospathseparator() + cCNPJ + hb_ospathseparator() + "htm"
   local cHtm := memoread( cPath + hb_ospathseparator() + "coblogin.htm" )
   local nI

   // cHTM contem arquivo modelo da pagina.

   outstd( "Content-type: text/html" + hb_OSNewLine() + hb_OSNewLine() ) // Obrigatorio 2 avancos de linha

   // Substitui a strings '{}' no modelo, pela conteudo da variavel corrrespondente.

   cHtm := strtran( cHtm, "{CNPJEMPRESA}", cCNPJ )
   cHtm := strtran( cHtm, "{CNPJCPFCLIENTE}", cCNPJCPFCliente )
   cHtm := strtran( cHtm, "{NOMECLIENTE}", cCliente )
   cHtm := strtran( cHtm, "{TESTACNPJCPF}", if( len( cCNPJCPFCliente ) == 14, "CNPJ", "CPF" ) )

   // Disponibiliza pagina HTML informativa ao usuario.
   for nI := 1 to mlcount( cHtm )
      outstd( memoline( cHtm,, nI ) )
   next

   return( NIL )


// Funcao auxiliar para disponibilizar pagina HTML para download de arquivos ao usuario.
static function SendDownload( cCNPJ, cCNPJCPFCliente, cCliente, cFileZip, aFiles )
   local cRaiz := pDirRaiz
   local cPath := cRaiz + hb_ospathseparator() + cCNPJ + hb_ospathseparator() + "htm"
   local cHtm := memoread( cPath + hb_ospathseparator() + "cobdownload.htm" )
   local nI
   local cUrlDownload := pURLScriptPHP
   local cTemp, cTemp2
   local cHtmIncluir
   local cHtmTabela
   local cLinha
   local nPosIncluir

   // cHTM possui o modelo 'cobdownload.htm'

   // Extrai do modelo o trecho que descreve a linha da tabela de arquivos para download
   // utiliza os comentarios "<!--Inicio_Tabela-->" e "<!--Fim_Tabela-->", como delimitadores
   if ( nPosIncluir := at( "<!--Inicio_Tabela-->", cHtm ) ) > 0 .and. ;
        ( nI := at( "<!--Fim_Tabela-->", cHtm ) ) > 0

      // cHTMTabela é o modelo de cada linha da tabela.
      cHtmTabela := subst( cHtm, nPosIncluir + len( "<!--Inicio_Tabela-->" ), nI - nPosIncluir - len( "<!--Inicio_Tabela-->" ) )
      // Remove o modelo da linha da tabela do modelo completo.
      cHtm := stuff( cHtm, nPosIncluir, nI + len( "<!--Fim_Tabela-->" ) - nPosIncluir, '' )

      // Gera uma linha por arquivo, através do modelo de linha de tabela.
      cLinha := ''
      for nI := 1 to len( aFiles )

         // Substitui string das variaveis do modelo da URL script PHP com as informacoes do arquivo.
         cTemp := STRTRAN( cUrlDownload, "{ZIP}", cFileZip )
         cTemp := STRTRAN( cTemp, "{FILE}", aFiles[ nI ] )
         // Substitui string das variaveis do modelo da linha de tabela com as informacoes do arquivo.
         cTemp2 := strtran( cHtmTabela, "{FILE}", aFiles[ nI ] )
         cTemp2 := strtran( cTemp2, "{URL}", "'" + cTemp + "'" )

         cLinha += cTemp2
      next
      // cLinha Contem todas as linhas HTML da tabela.
      // Inclui as linhas HTML na posicao original no modelo completo.
      cHtm := stuff( cHtm, nPosIncluir, 0, cLinha )

      // Disponibiliza pagina de download de arquivos ao usuario.
      outstd( "Content-type: text/html" + hb_OSNewLine() + hb_OSNewLine() ) // Obrigatorio 2 avancos de linha
      for nI := 1 to mlcount( cHtm )
         outstd( memoline( cHtm,, nI ) )
      next

   endif

   return( NIL )


// Funcao para adicionar as informacoes de cobranca ao banco de dados.
function IncluiAceite( h )
   local lOk := .F.
   local cRaiz := pDirRaiz
   local cPath
   local nI
   local nTimeout

// testa se pastas e arquivo de dados existe.
   if hb_direxists( cRaiz ) .and. ;
      hb_hHasKey( h, "CNPJEmpresa" ) .and. ! strempty( h[ "CNPJEmpresa" ] ) .and. ;
      hb_direxists( cPath := cRaiz + hb_ospathseparator() + h[ "CNPJEmpresa" ] + hb_ospathseparator() + "dbf" ) .and. ;
      file( cPath + hb_ospathseparator() + "aceite.dbf" )

      // Abre Banco de dados
      Set( _SET_DEFAULT, cPath )
      DBUseArea( .T., ;
                 , ;
                 "aceite.dbf", ;
                 "ACEITE", ;
                 .t., ;
                 .f. )
      if used()
         // Se disponivel
         // Define a chave de pesquisa: CNPJ+Codigo Cobranca+Numero Boleto.
         ACEITE->( ordsetfocus( "EMPT" ) )

         // Testa se todos os boletos da cobranca estao inclusos.
         nI := 1
         lOk := .T.
         while lOk .and. nI <= len( h[ "Boletos" ] )

            if ! ( ACEITE->( dbseek( padr( h[ "CNPJEmpresa" ] , 14 ) + ;
                                     h[ "CodBloq" ] + ;
                                     ( h[ "Boletos" ] )[ nI ] ) ) )
               // Se boleto nao encontrado na base de dados, inclui
               // Timeout de 3 segundos prevendo acessos intensos.
               nTimeout := hb_milliseconds() + 3000
               lOk := .F.
               while hb_milliseconds() < nTimeout
                  if ACEITE->( dbappend() )
                     ACEITE->CNPJEMP    := h[ "CNPJEmpresa" ]
                     ACEITE->CNPJCPFCLI := h[ "CNPJCPFCliente" ]
                     ACEITE->CODCOBRAN   := h[ "CodCobranca" ]
                     ACEITE->BOLETO    := ( h[ "Boletos" ] )[ nI ]
                     ACEITE->DTPOSTAGEM := AAAAMMDDtoD( h[ "DtPostagem" ] )
                     ACEITE->DTVENC    := AAAAMMDDtoD( h[ "DtUltVenc" ]  )
                     ACEITE->DTVALIDADE := AAAAMMDDtoD( h[ "DtValidade" ] )
                     ACEITE->DTENVIO   := date()
                     ACEITE->HRENVIO   := time()
                     ACEITE->DTACEITE  := date()
                     ACEITE->HRACEITE  := time()

                     ACEITE->( DBCommit() )
                     ACEITE->( DBRUnlock() )
                     lOk := .T.
                     exit
                  endif
                  hb_releasecpu() // Libera o processador
               enddo
            else
               // Se boleto encontrado,  atualiza envio caso ainda nao concluido.
               if empty( ACEITE->DTBAIXA )
                  nTimeout := hb_milliseconds() + 3000
                  lOk := .F.
                  while hb_milliseconds() < nTimeout
                     if ACEITE->( dbrlock() )
                        // Atualiza o aceite.
                        ACEITE->DTACEITE  := date()
                        ACEITE->HRACEITE  := time()
                        ACEITE->( DBCommit() )
                        ACEITE->( DBRUnlock() )
                        lOk := .T.
                        exit
                     endif
                     hb_releasecpu()
                  enddo

               endif
            endif
            nI ++
         enddo
         // salva evetuais informacoes em "cache" e fecha o banco de dados.
         DBCommit()
         DBCloseArea()

      endif

   endif
   return( lOk )



//------------------------------------------------------------------------------
// Funcoes Diversas
//------------------------------------------------------------------------------

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


// Converte String no formato AnoMesDia em tipo Date.
function AAAAMMDDtoD(  cData )
   local dData := DtVazia() // Usada apenas para obter o formato

   cData := RetNumeros( cData, .T., .T. ) // Remove todos os simbolos, retornando somente os numeros
   if len( cData ) == 8
      dData := ctod( subst( cData, 7, 2 ) + '/' + subst( cData, 5, 2 ) + '/' + left( cData, 4 ) )
   endif
   return( dData )

// Extrai apenas numeros de uma string
function RetNumeros( cValor, lExcluiPonto, lExcluiMenos )
   local cTemp := ''
   local cChar
   local cProcura := "0123456789"
   local nI

   if lExcluiPonto == NIL .or. lExcluiPonto == .F.
      cProcura += '.'
   endif
   if lExcluiMenos == NIL .or. lExcluiMenos == .F.
      cProcura += '-'
   endif

   for nI := 1 to len( cValor )
      cChar := subst( cValor, nI, 1 )
      if cChar $ cProcura
         cTemp += cChar
      endif
   next

   return( cTemp )
