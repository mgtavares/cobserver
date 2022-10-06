
// Define pagina de codigo e internacionalizacao
#define __CP_HOST__ "PT850"
#define __CP_TERM__ "PTISO"

// Define pasta raiz no servidor para o projeto.
#define pDirRaiz "/data/cobserver"


function main()
   local aParams := hb_aparams()
   local cToken
   local aC := { }
   local cCNPJEmpresa := ''
   local h := hash()

   HB_CDPSELECT( __CP_HOST__ )
   HB_SETTERMCP( __CP_TERM__, __CP_HOST__, .T. )

   // Define padrao banco de dados DBMS Foxpro
   RDDSETDEFAULT ( "BMDBFCDX" )

   if getenv( "REQUEST_METHOD" ) == "GET"
      // Se GET, testa parametro
      if empty( aParams )
         SendErro(  "GET Sem Parametros Informados" )
      elseif len( aParams ) != 1
         SendErro( "GET Paramentos Invalidos" )
      else


         if DecodificaToken( aParams[ 1 ], @cCNPJEmpresa )
            // Se CNPJ aceito, processa consulta
            if ConsultaAceite( cCNPJEmpresa, @aC )
               // Se consulta OK, devolve matriz com resultado
               SendJSON( aC )
            else
               SendErro( "Erro consulta base dados" )
            endif
         else
            SendErro( "GET Token Invalido" )
         endif
      endif
   else
      SendErro( "Somente GET sera' aceito" )
   endif

   return( NIL )

// Testa CNPJ recebido no formato de token
static function DecodificaToken( cToken, cCNPJEmpresa )
   local lOk

   cToken := k_DeCodificaToken( k_UrlToStr( cToken ) )
   cCNPJEmpresa := cToken

// Retorna Verdadeiro se CNPJ
   lOk := ! empty( cCNPJEmpresa ) .and. ;
          LEN( cCNPJEmpresa ) == 14


   return( lOk )

// Retorna uma mensagem de erro do WebService, no Formato JSON.
static function SendErro( cErro )
   local h := hash()

   h[ "Erro" ] := cErro

   outstd( "Content-type: application/json" + hb_OSNewLine() + hb_OSNewLine() ) // Obrigatorio 2 avancos de linha
   outstd( hb_jsonencode( h ) + hb_OSNewLine() )

   return( NIL )

// Retorna Matriz no formato JSON
static function SendJSON( h )

   outstd( "Content-type: application/json" + hb_OSNewLine() + hb_OSNewLine() ) // Obrigatorio 2 avancos de linha
   outstd( hb_jsonencode( h ) + hb_OSNewLine() )

   return( NIL )

// Executa a consulta a base de dados a partir do CNPJ empresa usuária.
function ConsultaAceite( cCNPJEmpresa, aC )
   local lOk := .F.
   local cRaiz := pDirRaiz
   local cPath
   local nI, nJ

   // Esvazia matriz de retorno
   aC := asize( aC, 0 )

// Testa se CNPJ corresponde a caminho e arquivo de dados no servidor.
   if hb_direxists( cRaiz ) .and. ;
      hb_direxists( cPath := cRaiz + hb_ospathseparator() + cCNPJEmpresa + hb_ospathseparator() + "dbf" ) .and. ;
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
         ACEITE->( ordsetfocus( "EMPP" ) ) // Ordena consulta por CNPJ.

         lOk := .T.
         if ACEITE->( dbseek( cCNPJEmpresa ) )
            // Se possui registros para empresa, posiciona no primeiro.
            // Obtem todos os boletos aceitos e devolve na matriz "aC"
            while ACEITE->CNPJEMP == cCNPJEmpresa
               if ( nI := ascan( aC, { | a | a[ "CodCobranca" ] == ACEITE->CODCOBRAN } ) ) == 0
                  // Uma matriz por Codigo de Cobranca existente por CNPJ
                  aadd( aC, hash() )
                  ( atail( aC ) )[ "CodCobranca" ]  := ACEITE->CODCOBRAN
                  ( atail( aC ) )[ "DtAceite" ]  := ACEITE->DTACEITE
                  ( atail( aC ) )[ "HrAceite" ] := ACEITE->HRACEITE
                  ( atail( aC ) )[ "Boletos" ]  := { }
                  nI := len( aC )
               endif
               if ( nJ := ascan( ( aC[ nI ] )[ "Boletos" ], { | a | a == ACEITE->BOLETO } ) ) == 0
                  // Adiciona cada boleto aceito na matriz de Cod.Cobranca respectiva.
                  aadd( ( aC[ nI ] )[ "Boletos" ], ACEITE->BOLETO )
               else
                  ( ( aC[ nI ] )[ "Boletos" ] )[ nJ ] := ACEITE->BOLETO // Prevalece o ultimo em caso de duplicidade
               endif
               // Avanca proximo registro
               ACEITE->( dbskip() )
            enddo
         endif
         // Fecha Banco de dados
         DBCommit()
         DBCloseArea()

      endif
   endif
   // Retorna Verdadeiro se consulta com sucesso.
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
