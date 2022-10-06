// Define pagina de codigo e internacionalizacao
#define __CP_HOST__ "PT850"
#define __CP_TERM__ "PTISO"

// Define pasta raiz no servidor para o projeto.
#define pDirRaiz "/data/cobserver"

function main()
   local aParams := hb_aparams()
   local cToken
   local cCGCCPF := ''
   local h := hash()

   HB_CDPSELECT( __CP_HOST__ )
   HB_SETTERMCP( __CP_TERM__, __CP_HOST__, .T. )

// Define padrao banco de dados DBMS Foxpro
   RDDSETDEFAULT ( "BMDBFCDX" )

   if getenv( "REQUEST_METHOD" ) == "GET"

      if empty( aParams )
         SendErro(  "GET Sem Parametros Informados" )
      elseif len( aParams ) != 1
         SendErro( "GET Paramentos Invalidos" )
      else

         // Obtem estrutura passada como parametro
         if DecodificaToken( aParams[ 1 ], @h )
            // Se decodificou correto, processa a alteracao na base de dados
            if AlteraAceite( h )
               SendOk()
            else
               SendErro( "Erro alterar base dados" )
            endif

         else
            SendErro( "GET Token Invalido" )
         endif

      endif
   else
      SendErro( "Somente GET sera aceito" )
   endif

   return( NIL )

// Decodifica token, obtendo a estrutura JSON.
static function DecodificaToken( cToken, h )
   local lOk

   cToken := k_DeCodificaToken( k_UrlToStr( cToken ) )

   // Testa apenas parametros essenciais:"Matriz de Boletos, CNPJ e Codigo Cobranca".
   lOk := ! empty( cToken ) .and. ;
          hb_jsondecode( cToken, @h ) > 0 .and. ;
          hb_hHasKey( h, "Boletos" ) .and. ;
          valtype( h[ "Boletos" ] ) == "A" .and. ;
          len( h[ "Boletos" ] ) > 0 .and. ;
          hb_hHasKey( h, "CNPJEmpresa" ) .and. valtype( h[ "CNPJEmpresa" ] ) == "C" .and. ! strempty( h[ "CNPJEmpresa" ] ) .and. ;
          hb_hHasKey( h, "CodCobranca" ) .and. valtype( h[ "CodCobranca" ] ) == "C" .and. ! strempty( h[ "CodCobranca" ] )

   return( lOk )

// Retorna Erro em formato JSON
static function SendErro( cErro )
   local h := hash()

   h[ "Erro" ] := cErro

   outstd( "Content-type: application/json" + hb_OSNewLine() + hb_OSNewLine() ) // Obrigatorio 2 avancos de linha
   outstd( hb_jsonencode( h ) + hb_OSNewLine() )

   return( NIL )

// Retorna bem sucessido em formato JSON
static function SendOk()
   local h := hash()

   h[ "OK" ] := "OK"

   outstd( "Content-type: application/json" + hb_OSNewLine() + hb_OSNewLine() ) // Obrigatorio 2 avancos de linha
   outstd( hb_jsonencode( h ) + hb_OSNewLine() )

   return( NIL )

// Processa alteração no banco de dados
function AlteraAceite( h )
   local lOk := .F.
   local cRaiz := pDirRaiz
   local cPath
   local nI, nJ
   local nTimeout

   // Testa se CNPJ corresponde a caminho e arquivo de dados no servidor.
   if hb_direxists( cRaiz ) .and. ;
      hb_direxists( cPath := cRaiz + hb_ospathseparator() + h[ "CNPJEmpresa" ] + hb_ospathseparator() + "dbf" ) .and. ;
      file( cPath + hb_ospathseparator() + "aceite.dbf" )

      // Se existe banco de dados para CNPJ, utiliza o caminho como "default"
      Set( _SET_DEFAULT, cPath )
      DBUseArea( .T., ;
                 , ;
                 "aceite.dbf", ;
                 "ACEITE", ;
                 .t., ;
                 .f. )
      if used()
         // Se abriu com sucesso, processa
         ACEITE->( ordsetfocus( "EMPT" ) ) // Ordem por CNPJ + CodCobranca + Boleto
         nI := 1
         lOk := .T.
         // percorre a matriz de boletos a aplicar no banco de dados
         while lOk .and. nI <= len( h[ "Boletos" ] )

            if hb_hHasKey( h, "DELETE" )
               // Se matriz de boletos com comando DELETE, exclui o registro
               lOk := .F.
               if ( ACEITE->( dbseek( padr( h[ "CNPJEmpresa" ] , 14 ) + ;
                                      h[ "CodCobranca" ] + ;
                                      ( h[ "Boletos" ] )[ nI ] ) ) )
                  // Se registro encontrado, exclui
                  nTimeout := hb_milliseconds() + 3000
                  while hb_milliseconds() < nTimeout
                     if ACEITE->( dbrlock() )
                        ACEITE->( dbdelete() )
                        ACEITE->( DBCommit() )
                        ACEITE->( DBRUnlock() )
                        lOk := .T.
                        exit
                     endif
                     hb_releasecpu()
                  enddo
               endif
            else
               // Se ALTERAR OU INCLUIR
               if ! ( ACEITE->( dbseek( padr( h[ "CNPJEmpresa" ] , 14 ) + ;
                                        h[ "CodCobranca" ] + ;
                                        ( h[ "Boletos" ] )[ nI ] ) ) )
                  // Se nao localizado, inclui
                  lOk := .F.
                  nTimeout := hb_milliseconds() + 3000
                  while hb_milliseconds() < nTimeout
                     if ACEITE->( dbappend() )
                        ACEITE->CNPJEMP   := h[ "CNPJEmpresa" ]
                        ACEITE->CODCOBRAN := h[ "CodCobranca" ]
                        ACEITE->BOLETO    := ( h[ "Boletos" ] )[ nI ]
                        // Inclui informacoes recebidas
                        SalvaAceite( h )

                        ACEITE->( DBCommit() )
                        ACEITE->( DBRUnlock() )
                        lOk := .T.
                        exit
                     endif
                     hb_releasecpu()
                  enddo
               else
                  // Se localizou, atualiza envio se nao baixada
                  if empty( ACEITE->DTBAIXA )
                     lOk := .F.
                     nTimeout := hb_milliseconds() + 3000
                     while hb_milliseconds() < nTimeout
                        if ACEITE->( dbrlock() )
                           // Altera com informações recebidas
                           SalvaAceite( h )

                           ACEITE->( DBCommit() )
                           ACEITE->( DBRUnlock() )
                           lOk := .T.
                           exit
                        endif
                        hb_releasecpu()
                     enddo

                  endif
               endif
            endif
            nI ++
         enddo
         // Fecha o banco de dados
         DBCommit()
         DBCloseArea()
      endif
   endif
   return( lOk )

// Aplica as informacoes da estrutura recebida pelo WebService ao registro do banco de dados selecionado.
static function SalvaAceite( h )

   // Testa cada item da estrutura e altera se presente e com valores validos.

   if hb_hHasKey( h, "CNPJCPF"  ) .and. valtype( h[ "CNPJCPF" ] ) == "C" .and. len( h[ "CNPJCPF" ] ) > 0
      ACEITE->CNPJCPFCLI := h[ "CNPJCPF" ]
   endif
   if hb_hHasKey( h, "DtPostagem"  ) .and. valtype( h[ "DtPostagem" ] ) == "C" .and. len( h[ "DtPostagem" ] ) == 8
      ACEITE->DTPOSTAGEM := AAAAMMDDtoD( h[ "DtPostagem" ] )
   endif
   if hb_hHasKey( h, "DtUltVenc"  ) .and. valtype( h[ "DtUltVenc" ] ) == "C" .and. len( h[ "DtUltVenc" ] ) == 8
      ACEITE->DTVENC    := AAAAMMDDtoD( h[ "dUltVenc" ]  )
   endif
   if hb_hHasKey( h, "DtValidade"  ) .and. valtype( h[ "DtValidade" ] ) == "C" .and. len( h[ "DtValidade" ] ) == 8
      ACEITE->DTVALIDADE := AAAAMMDDtoD( h[ "DtValidade" ] )
   endif
   if hb_hHasKey( h, "DtEnvio"  ) .and. valtype( h[ "DtEnvio" ] ) == "C" .and. len( h[ "DtEnvio" ] ) == 8
      ACEITE->DTENVIO   := AAAAMMDDtoD( h[ "DtEnvio" ] )
   else
      // Utiliza data do sistema se valor omitido.
      ACEITE->DTENVIO   := date()
   endif
   if hb_hHasKey( h, "HrEnvio"  ) .and. valtype( h[ "HrEnvio" ] ) == "C" .and. len( h[ "HrEnvio" ] ) == 8
      ACEITE->HRENVIO   := h[ "HrEnvio" ]
   else
      // Utiliza data do sistema se valor omitido.
      ACEITE->HRENVIO   := time()
   endif
   if hb_hHasKey( h, "DtAceite"  ) .and. valtype( h[ "DtAceite" ] ) == "C" .and. len( h[ "DtAceite" ] ) == 8
      ACEITE->DTACEITE  := AAAAMMDDtoD( h[ "dAceite" ] )
   endif
   if hb_hHasKey( h, "HrAceite"  ) .and. valtype( h[ "HrAceite" ] ) == "C" .and. len( h[ "HrAceite" ] ) == 8
      ACEITE->HRACEITE   := h[ "HrAceite" ]
   endif
   if hb_hHasKey( h, "DtBaixa"  ) .and. valtype( h[ "DtBaixa" ] ) == "C" .and. len( h[ "DtBaixa" ] ) == 8
      ACEITE->DTBAIXA  := AAAAMMDDtoD( h[ "DtBaixa" ] )
   endif
   if hb_hHasKey( h, "HrBaixa"  ) .and. valtype( h[ "HrBaixa" ] ) == "C" .and. len( h[ "HrBaixa" ] ) == 8
      ACEITE->HRBAIXA   := h[ "HrBaixa" ]
   endif

   return( NIL )

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
