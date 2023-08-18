Class Custom.ERP.StockHandler Extends %RegisteredObject
{

ClassMethod StockGetUpdate(pPrescNo, pLoc) As %String
{
	
	Set tSC = $$$OK
	Set resp = "1"
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	
		
		Set tItems = ""
		set tPAQue1Id = $order(^PAQUE1(0,"PrescNo",pPrescNo,""))
		if tPAQue1Id '= ""
		{
			set tObjPAQue1 = ##class(User.PAQue1).%OpenId(tPAQue1Id)
			set tStatus = tObjPAQue1.QUE1PharmStatus
			//set ^zjb("EnviaConsulta",2)="2 tStatus "_tStatus
		
			if "A,P" '[ $extract($get(tStatus),1)
			{
				Quit
			}
		
		}
	
		If ((pPrescNo'="")&&(pLoc'=""))
		{
			//set ^zjb("EnviaConsulta",3)="3"
			Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set StockUpdateMsg.FacilityCode = "1000"
			Set StockUpdateMsg.User = $g(%session.Data("LOGON.USERCODE"))
			if $g(%session.Data("LOGON.USERCODE")) = ""
			{
				Set StockUpdateMsg.User = "Default3"
			}
			// Codigo Bodega SAP
			Set StockUpdateMsg.LocationCode = $Piece(^CTLOC(+pLoc),"^",55)
			//Set StockUpdateMsg.LogisticLocation = $Piece($Piece(^CTLOC(+pLoc),"^",77),";",1)
			Set StockUpdateMsg.MovementCode = "S001"

			Set tOEORDRowId = ""
			Set tOEORDRowId = $Order(^OEORD(0,"PrescNo",pPrescNo,tOEORDRowId))
			while (tOEORDRowId){
				Set tOEORIChildsub = ""
				Set tOEORIChildsub = $Order(^OEORD(0,"PrescNo",pPrescNo,tOEORDRowId,tOEORIChildsub))
				while(tOEORIChildsub){
					
					set tItemPharmacyState = ""
					set tItemPharmacyState = $$pharmst^COEOrdItem6(tOEORDRowId_"||"_tOEORIChildsub)
					
					if "A,P" '[ $extract($get(tItemPharmacyState),1)
					{
						Set tOEORIChildsub = $Order(^OEORD(0,"PrescNo",pPrescNo,tOEORDRowId,tOEORIChildsub))
						continue
					}
					
					Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
					Set tOEORIItmMastDR = $Piece(^OEORD(tOEORDRowId,"I",tOEORIChildsub,1),"^",2) // OEORI_ItmMast_DR
				
					//Codigo Externo
					set tCodItemERP = ""
					set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
					set tLocalHomologacionERP = "SAP"
					if tLocalHomologacionERP '=""
					{
						set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
						set tCodItemERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
					}
				
				
					Set tOEORIPhQtyOrd = $Piece(^OEORD(tOEORDRowId,"I",tOEORIChildsub,1),"^",12) // OEORI_PhQtyOrd
					Set tOEORIRowId = tOEORDRowId_"||"_tOEORIChildsub
					Set tOEORIPendingPhQtyOrd = 0
					// Packed,Collected,Check,Uncollected
					&SQL(select sum(DSP_Qty)-sum(DSP_ReturnQty) into :tOEORIPendingPhQtyOrd from sqluser.OE_Dispensing where DSP_OEORE_ParRef->OEORE_OEORI_ParRef = :tOEORIRowId and DSP_Status in ('P','C','K'))
					If ((tOEORIPhQtyOrd-tOEORIPendingPhQtyOrd)>0)
					{
						
						set tItemStockId=""
						set tItemStockId = $order(^INCI(0,"ARCIM_DR",+tOEORIItmMastDR,""))
						if $get(tItemStockId) '= ""
						{
							
							set tTimeUpdate = 1
							set tTimeUpdate = ..ValidateTimeUpdate(tOEORIItmMastDR,pLoc,"ARCIM","1")
							//set ^zjb("EnviaConsulta","3.1",tItemStockId)="tItemStockId "_tItemStockId_" tTimeUpdate "_tTimeUpdate
							if tTimeUpdate = 0 
							{
								Set tOEORIChildsub = $Order(^OEORD(0,"PrescNo",pPrescNo,tOEORDRowId,tOEORIChildsub))
								continue
							}
							Set tARCIMCode = $Piece(^ARCIM($Piece(tOEORIItmMastDR,"||",1),$Piece(tOEORIItmMastDR,"||",2),1),"^",1)
							Set tARCIMDesc = $Piece(^ARCIM($Piece(tOEORIItmMastDR,"||",1),$Piece(tOEORIItmMastDR,"||",2),1),"^",2)
							Set tARCIMUOMDR = $Piece(^ARCIM($Piece(tOEORIItmMastDR,"||",1),$Piece(tOEORIItmMastDR,"||",2),1),"^",4)
					
							if tCodItemERP '= ""
							{
								Set StockItem.StockItemCode=tCodItemERP
								set ^HomologaCodERP(%session.SessionId,tCodItemERP)=tARCIMCode
							}
							else
							{
								Set StockItem.StockItemCode = tARCIMCode
								set ^HomologaCodERP(%session.SessionId,tARCIMCode)=tARCIMCode
							}
							//Para fines de Homologar los datos devuelta
					
					
							Set StockItem.StockItemDesc = tARCIMDesc
							//set ^zjb("EnviaConsulta",4,tARCIMCode)="Cod "_StockItem.StockItemCode_" Desc "_tARCIMDesc
							If (tARCIMUOMDR'="")
							{ 
								Set tUOMCode = $Piece(^CT("UOM",tARCIMUOMDR),"^",1)
								Set StockItem.UOMCode = tUOMCode
							}
							//Set tItems = tItems _ tARCIMCode _ ";"
							Set tSC = StockUpdateMsg.Items.Insert(StockItem)
						}
					}
					Set tOEORIChildsub = $Order(^OEORD(0,"PrescNo",pPrescNo,tOEORDRowId,tOEORIChildsub))
									 
				}
				Set tOEORDRowId = $Order(^OEORD(0,"PrescNo",pPrescNo,tOEORDRowId))
			}
		
			if StockUpdateMsg.Items.Count() > 0
			{
				// Enviar Mensaje
				Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
				Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
				set tWSSend.Timeout = 30
			
				//Traer la localización de WS según parametros
				Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
				If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
				//set ^zjb("EnviaConsulta",5)="5 "_tSC
				Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
				//set ^zjb("EnviaConsulta",6)="6 "_tSC
				Quit:$System.Status.IsError(tSC)
		
				Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
				//set ^zjb("EnviaConsulta",7)="7 "_tSC
				Set tSC = tWSSend.SendEvent(StockUpdateMsg,	.pResponse)
		
				//set ^zjb("EnviaConsulta",8)="8 "_tSC
				//set ^zjb("EnviaConsulta",9)=pResponse
		
		
				//if pResponse.ERPResponse.ErrorDescription '= "" set ^zjb("EnviaConsulta",9)="9 "_pResponse.ERPResponse.ErrorDescription
				If $System.Status.IsError(tSC) Quit
		
				if (pResponse.ERPResponse.IsError) Quit
				
				set pResponse.LocationCode = $Piece(^CTLOC(+pLoc),"^",1)
				//set ^zjb("Update Stock",2)="2 "_pResponse.LocationCode
		
				set tFinalResponse = ##class(Custom.Nexus.WS.ResponseEvent).%New()
		
				set tSC = ##class(Custom.Nexus.WSEventHandler.StockHandler).StockReGenerator(pResponse,.tFinalResponse)
				kill ^HomologaCodERP(%session.SessionId)
				//set ^zjb("Update Stock",3)="3 "_tSC
		
			}
		}
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			Set resp= $System.Status.GetErrorText(tSC)
		}
		Else
		{
			//set ^zjb("EnviaConsulta",10)="10 "_tSC
			Set tSC = tException.AsStatus()
			Set resp= $System.Status.GetErrorText(tSC)
			//set ^zjb("EnviaConsulta",11)="11 "_tSC
		}
	}
	//set ^zjb("EnviaConsulta",12)="12 "_tSC
	Quit resp
}

ClassMethod StockGetUpdateFromQuery(pLocationDescription, pItemDescription) As %String
{
	
	Set tSC = $$$OK
	Set resp = "1"
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		set tOMNIOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("OMNI.WS.StockFarmacia") 
		if pLocationDescription = "" quit
		if pItemDescription = "" quit
		//busca datos del local receptor
		set (tLoc,tERPLoc,tOMNIArea,tLocCode,tDispType,tExtSystemType,tHL7Outbound) = ""
		&SQL(SELECT CTLOC_RowID, CTLOC_PagerNo, CTLOC_TelephoneExt, CTLOC_Code,CTLOC_ExternalInfoSystem,CTLOC_HL7OrdersLink
			INTO :tLoc, :tERPLoc, :tOMNIArea, :tLocCode,:tExtSystemType,:tHL7Outbound
			FROM SQLUser.CT_Loc
			WHERE  (%ALPHAUP CTLOC_Desc = %ALPHAUP :pLocationDescription)
			)

		if tERPLoc ="" && tOMNIArea="" quit
		
		//if tOMNIArea'=""
		if $get(tExtSystemType) = "GENERIC", tHL7Outbound'=""
		{
			//Salir si no está activa la integracion
			if 'tOMNIOn quit  
			if tOMNIArea="" quit
			set tDispType="OMNI"
		}
		else
		{
			//Salir si no está activa la integracion
			if 'tIntegrationOn quit	
		}
						
		//busca datos del item de stock		
		set (tINCIId,tARCIMCode) = ""
		&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  (%ALPHAUP INCI_Desc = %ALPHAUP :pItemDescription)
			)
		if SQLCODE'=0 set tINCIId = ""
		
		if tINCIId = ""
		{
			&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  (%ALPHAUP INCI_Code = %ALPHAUP :pItemDescription)
			)
			if SQLCODE'=0 set tINCIId = ""
		}
		
		if tINCIId = ""
		{
			&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  %id = :pItemDescription
			)
			if SQLCODE'=0 set tINCIId = ""
		}
		
		if tINCIId ="" || tARCIMCode="" quit
		
		
		set tTimeUpdate = 1
		//set tTimeUpdate = ..ValidateTimeUpdate(tINCIId,tLoc,"INCI","1",tDispType)
		set tTimeUpdate = ..ValidateTimeUpdate(tINCIId,tLoc,"INCI","1")
		if tTimeUpdate = 0 quit
		
		
		// Busca saldo de stock via integracion
		if tDispType="OMNI"
		{
			set tCodERP = tARCIMCode
			set tSC = ##class(Custom.ERP.StockWSHandler).GetStockOMNI(tOMNIArea, "", tCodERP, "", .pResponse)
			Quit:$System.Status.IsError(tSC)
			
			set pResponse.LocationCode = tLocCode
		}	
		else
		{
			//Codigo Item
			set tCodERP = ..GetItemCodeERP(tINCIId)
			set tDescERP = pItemDescription
			set tSC = ##class(Custom.ERP.StockWSHandler).GetStockERP(tERPLoc, tCodERP, tDescERP, .pResponse)
			
			set pResponse.LocationCode = tLocCode	
		}
		
		//actualiza el stock
		set tFinalResponse = ##class(Custom.Nexus.WS.ResponseEvent).%New()
		set ^HomologaCodERP(%session.SessionId,tCodERP)=tARCIMCode
		set tSC = ##class(Custom.Nexus.WSEventHandler.StockHandler).StockReGenerator(pResponse,.tFinalResponse)
		kill ^HomologaCodERP(%session.SessionId)
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			Set resp= $System.Status.GetErrorText(tSC)
		}
		Else
		{
			set ^zjb("EnviaConsulta",10)="10 "_tSC
			Set tSC = tException.AsStatus()
			Set resp= $System.Status.GetErrorText(tSC)
			set ^zjb("EnviaConsulta",11)="11 "_tSC
		}
	}
	Quit resp
	
	
	/*  RESPALDO CLASE ANTIGUA
	Set tSC = $$$OK
	Set resp = "1"
	//set ^zjb("EnviaConsultaQ",0)="0 pLocationDescription "_pLocationDescription_" pItemDescription "_pItemDescription  
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	
		
		//set ^zjb("EnviaConsulta",1)="1 "_pLocationDescription
		
		if pLocationDescription = "" quit
		if pItemDescription = "" quit
		
		set tLoc = ""
		set tERPLoc = ""
		&SQL(SELECT CTLOC_RowID, CTLOC_PagerNo
			INTO :tLoc, :tERPLoc
			FROM SQLUser.CT_Loc
			WHERE  (%ALPHAUP CTLOC_Desc = %ALPHAUP :pLocationDescription)
			)
		if SQLCODE'=0 quit
		if tERPLoc ="" || tLoc ="" quit
				
		
		set tINCIId = ""
		set tARCIMCode = ""
		
		
		&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  (%ALPHAUP INCI_Desc = %ALPHAUP :pItemDescription)
			)
		if SQLCODE'=0 set tINCIId = ""
		
		if tINCIId = ""
		{
			&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  (%ALPHAUP INCI_Code = %ALPHAUP :pItemDescription)
			)
			if SQLCODE'=0 set tINCIId = ""
		}
		
		if tINCIId = ""
		{
			&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  %id = :pItemDescription
			)
			if SQLCODE'=0 set tINCIId = ""
		}
		
		if tINCIId ="" || tARCIMCode="" quit
		
		
		set tTimeUpdate = 1
		set tTimeUpdate = ..ValidateTimeUpdate(tINCIId,tLoc,"INCI","1")
		if tTimeUpdate = 0 quit
		
		
		///Codigo Item
		set tCodERP = ..GetItemCodeERP(tINCIId)
			
		
		//set ^zjb("EnviaConsultaQ",3)="3"
		Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
		Set StockUpdateMsg.FacilityCode = "1000"
		Set StockUpdateMsg.User = $g(%session.Data("LOGON.USERCODE"))
		if $g(%session.Data("LOGON.USERCODE")) = ""
		{
			Set StockUpdateMsg.User = "Default"
		}
		// Codigo Bodega SAP
		Set StockUpdateMsg.LocationCode = tERPLoc
		Set StockUpdateMsg.MovementCode = "S001"

	    
		
		Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
		Set StockItem.StockItemCode=tCodERP
		set ^HomologaCodERP(%session.SessionId,tCodERP)=tARCIMCode
		Set StockItem.StockItemDesc = pItemDescription
		
		
		Set tSC = StockUpdateMsg.Items.Insert(StockItem)
		
		
		
		// Enviar Mensaje
		Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
		Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
		set tWSSend.Timeout = 30
			
		//Traer la localización de WS según parametros
		Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
		If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
		//set ^zjb("EnviaConsulta",5)="5 "_tSC
		Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
		//set ^zjb("EnviaConsulta",6)="6 "_tSC
		Quit:$System.Status.IsError(tSC)
		
		Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
		//set ^zjb("EnviaConsulta",7)="7 "_tSC
		Set tSC = tWSSend.SendEvent(StockUpdateMsg,	.pResponse)
		//set ^zjb("EnviaConsulta",8)="8 "_tSC
		//set ^zjb("EnviaConsulta",9)=pResponse
		
		
		//if pResponse.ERPResponse.ErrorDescription '= "" set ^zjb("EnviaConsulta",9)="9 "_pResponse.ERPResponse.ErrorDescription
		If $System.Status.IsError(tSC) Quit
		if (pResponse.ERPResponse.IsError) quit
		
		set pResponse.LocationCode = $Piece(^CTLOC(+tLoc),"^",1)
		//set ^zjb("Update Stock",2)="2 "_pResponse.LocationCode
		
		set tFinalResponse = ##class(Custom.Nexus.WS.ResponseEvent).%New()
		
		set tSC = ##class(Custom.Nexus.WSEventHandler.StockHandler).StockReGenerator(pResponse,.tFinalResponse)
		kill ^HomologaCodERP(%session.SessionId)
		//set ^zjb("Update Stock",3)="3 "_tSC
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			Set resp= $System.Status.GetErrorText(tSC)
		}
		Else
		{
			//set ^zjb("EnviaConsulta",10)="10 "_tSC
			Set tSC = tException.AsStatus()
			Set resp= $System.Status.GetErrorText(tSC)
			//set ^zjb("EnviaConsulta",11)="11 "_tSC
		}
	}
	//set ^zjb("EnviaConsultaQ",12)="12 "_tSC_" resp "_resp
	Quit resp
	
	*/
}

ClassMethod StockGetUpdateFromStockItem(pStockId, pLocId) As %String
{
	Set tSC = $$$OK
	Set resp = "1"
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia") 
		set tOMNIOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("OMNI.WS.StockFarmacia") 
		
		if pLocId = "" quit
		if pStockId = "" quit
		
		//busca datos del local receptor
		set (tLoc,tERPLoc,tOMNIArea,tLocCode,tDispType,tHL7Outbound) = ""
		&SQL(SELECT CTLOC_RowID, CTLOC_PagerNo, CTLOC_TelephoneExt, CTLOC_Code,CTLOC_ExternalInfoSystem,CTLOC_HL7OrdersLink
			 INTO :tLoc, :tERPLoc, :tOMNIArea, :tLocCode,:tExtSystemType,:tHL7Outbound
			 FROM SQLUser.CT_Loc
			 WHERE  %id = :pLocId
		)
		
				
		if SQLCODE'=0 quit
		if tERPLoc ="" && tOMNIArea="" quit
		
		if tExtSystemType ="GENERIC",tHL7Outbound'=""
		{
			if 'tOMNIOn quit
			if tOMNIArea="" quit
			set tDispType="OMNI"
		}
		else
		{
			//Salir si no está activa la integracion
			if 'tIntegrationOn Quit	
		}
		
		//busca datos del item de stock		
		set (tINCIId,tARCIMCode) = ""
		&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  %Id = :pStockId
		)
		if SQLCODE'=0 quit
		if tINCIId ="" || tARCIMCode="" quit
		
		
		set tTimeUpdate = 1
		set tTimeUpdate = ..ValidateTimeUpdate(tINCIId,tLoc,"INCI","1") //,tDispType)
		if tTimeUpdate = 0 quit
		
		
		// Busca saldo de stock via integracion
		if tDispType="OMNI"
		{
			set tCodERP = tARCIMCode
			
			set tSC = ##class(Custom.ERP.StockWSHandler).GetStockOMNI(tOMNIArea, "",tCodERP, "",.pResponse)
			set ^zorl("stockup",97)=tSC
			Quit:$System.Status.IsError(tSC)
			
			set pResponse.LocationCode = tLocCode
		}	
		else 
		{ 
			//Codigo Item
			set tCodERP = ..GetItemCodeERP(tINCIId)
			set tDescERP = "Description"
			
			set tSC = ##class(Custom.ERP.StockWSHandler).GetStockERP(tERPLoc, tCodERP, tDescERP, .pResponse)
			
			set pResponse.LocationCode = tLocCode
		}
		
		//actualiza el stock
		set tFinalResponse = ##class(Custom.Nexus.WS.ResponseEvent).%New()
		set ^HomologaCodERP(%session.SessionId,tCodERP)=tARCIMCode
		set tSC = ##class(Custom.Nexus.WSEventHandler.StockHandler).StockReGenerator(pResponse,.tFinalResponse)
		kill ^HomologaCodERP(%session.SessionId)
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			Set resp= $System.Status.GetErrorText(tSC)
		}
		Else
		{
			Set tSC = tException.AsStatus()
			Set resp= $System.Status.GetErrorText(tSC)
		}
	}
	
	Quit resp
	
	/*  CODIGO ANTIGUO MOMENTANEO
	Set tSC = $$$OK
	Set resp = "1"
	//set ^zjb("EnviaConsultaStock",0)="0 pStockId "_pStockId_" pLocId "_pLocId  
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	
		
		//set ^zjb("EnviaConsulta",1)="1 "_pLocationDescription
		
		if pLocId = "" quit
		if pStockId = "" quit
		
		set tLoc = ""
		set tERPLoc = ""
		&SQL(SELECT CTLOC_RowID, CTLOC_PagerNo
			INTO :tLoc, :tERPLoc
			FROM SQLUser.CT_Loc
			WHERE  %id = :pLocId
			)
		if SQLCODE'=0 quit
		if tERPLoc ="" || tLoc ="" quit
				
		
		set tINCIId = ""
		set tARCIMCode = ""
		&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  %Id = :pStockId
			)
		if SQLCODE'=0 quit
		if tINCIId ="" || tARCIMCode="" quit
		
		
		set tTimeUpdate = 1
		set tTimeUpdate = ..ValidateTimeUpdate(tINCIId,tLoc,"INCI","1")
		if tTimeUpdate = 0 quit
		
		
		///Codigo Item
		set tCodERP = ..GetItemCodeERP(tINCIId)
			
		
		//set ^zjb("EnviaConsultaQ",3)="3"
		Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
		Set StockUpdateMsg.FacilityCode = "1000"
		Set StockUpdateMsg.User = $g(%session.Data("LOGON.USERCODE"))
		if $g(%session.Data("LOGON.USERCODE")) = ""
		{
			Set StockUpdateMsg.User = "Default1"
		}
		// Codigo Bodega SAP
		Set StockUpdateMsg.LocationCode = tERPLoc
		Set StockUpdateMsg.MovementCode = "S001"

	    
		
		Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
		Set StockItem.StockItemCode=tCodERP
		set ^HomologaCodERP(%session.SessionId,tCodERP)=tARCIMCode
		Set StockItem.StockItemDesc = "Description"
		
		
		Set tSC = StockUpdateMsg.Items.Insert(StockItem)
		
		
		
		// Enviar Mensaje
		Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
		Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			
		//Traer la localización de WS según parametros
		Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
		If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
		//set ^zjb("EnviaConsulta",5)="5 "_tSC
		Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
		//set ^zjb("EnviaConsulta",6)="6 "_tSC
		Quit:$System.Status.IsError(tSC)
		
		Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
		//set ^zjb("EnviaConsulta",7)="7 "_tSC
		Set tSC = tWSSend.SendEvent(StockUpdateMsg,	.pResponse)
		//set ^zjb("EnviaConsulta",8)="8 "_tSC
		//set ^zjb("EnviaConsulta",9)=pResponse
		
		
		
		if pResponse.ERPResponse.IsError quit
		If $System.Status.IsError(tSC) Quit
		if (pResponse.ERPResponse.IsError) Quit
		
		set pResponse.LocationCode = $Piece(^CTLOC(+tLoc),"^",1)
		//set ^zjb("Update Stock",2)="2 "_pResponse.LocationCode
		
		set tFinalResponse = ##class(Custom.Nexus.WS.ResponseEvent).%New()
		
		set tSC = ##class(Custom.Nexus.WSEventHandler.StockHandler).StockReGenerator(pResponse,.tFinalResponse)
		kill ^HomologaCodERP(%session.SessionId)
		//set ^zjb("Update Stock",3)="3 "_tSC
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			Set resp= $System.Status.GetErrorText(tSC)
		}
		Else
		{
			//set ^zjb("EnviaConsulta",10)="10 "_tSC
			Set tSC = tException.AsStatus()
			Set resp= $System.Status.GetErrorText(tSC)
			//set ^zjb("EnviaConsulta",11)="11 "_tSC
		}
	}
	//set ^zjb("EnviaConsultaStock",12)="12 "_tSC_" resp "_resp
	Quit resp
	*/
}

ClassMethod StockGetUpdateFromOrder(pLocId, pItemId, ptime As %String = "1") As %String
{
	Set tSC = $$$OK
	Set resp = "1"
	//set ^zjb("EnviaConsulta",0)="0 pLocId "_pLocId_" pItemId "_pItemId  
	Try
	{
		set tSession = ""
		set tSession = %session.SessionId
		//set tSession = "tSessionTestErp"
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	
		
		
		
		if pLocId = "" quit
		if pItemId = "" quit
		
		set tLoc = ""
		set tERPLoc = ""
		&SQL(SELECT CTLOC_RowID, CTLOC_PagerNo
			INTO :tLoc, :tERPLoc
			FROM SQLUser.CT_Loc
			WHERE  %Id = :pLocId
			)
		if SQLCODE'=0 quit
		if (tERPLoc ="") || (tLoc ="") quit
		
		//set ^zjb("EnviaConsulta",1)="1 "_pItemId		
		
		set tItmMastId = ""
		set tARCIMCode = ""
		&SQL(SELECT %id, ARCIM_Code
			INTO :tItmMastId, :tARCIMCode
			FROM SQLUser.ARC_ItmMast
			WHERE %Id = :pItemId
			)
		if SQLCODE'=0 quit
		if (tItmMastId ="") || (tARCIMCode="") quit
		
		set tItemStockId=""
		set tItemStockId = $order(^INCI(0,"ARCIM_DR",+tItmMastId,""))
		
		if $get(tItemStockId) = "" quit
						
		
		
		set tTimeUpdate = 1
		set tTimeUpdate = ..ValidateTimeUpdate(tItmMastId,tLoc,"ARCIM",ptime)
		if tTimeUpdate = 0 quit
		
		//set ^zjb("EnviaConsulta",2)="2 "_pItemId
		
		///Codigo Item
		set tCodERP = ""
		set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
		set tLocalHomologacionERP = "SAP"
		
		if tLocalHomologacionERP '=""
		{
			set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
			set tCodERP = ..GetItemExtCodeByLoc(tItmMastId,tERPLocationId)
					
		}	
		
		if tCodERP = "" set tCodERP = tARCIMCode
		
		//set ^zjb("EnviaConsulta",3)="3 tERPLoc "_tERPLoc_" tCodERP "_tCodERP  
		Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
		Set StockUpdateMsg.FacilityCode = "1000"
		Set StockUpdateMsg.User = $g(%session.Data("LOGON.USERCODE"))
		if $g(%session.Data("LOGON.USERCODE")) = ""
		{
			Set StockUpdateMsg.User = "Default2"
		}
		// Codigo Bodega SAP
		Set StockUpdateMsg.LocationCode = tERPLoc
		Set StockUpdateMsg.MovementCode = "S001"


		Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
		Set StockItem.StockItemCode=tCodERP
		set ^HomologaCodERP(tSession,tCodERP)=tARCIMCode
		Set StockItem.StockItemDesc = "Description"
		
		
		Set tSC = StockUpdateMsg.Items.Insert(StockItem)
		
		
		
		// Enviar Mensaje
		Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
		Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			
		//Traer la localización de WS según parametros
		Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
		If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
		//set ^zjb("EnviaConsulta",5)="5 "_tSC
		Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
		//set ^zjb("EnviaConsulta",6)="6 "_tSC
		Quit:$System.Status.IsError(tSC)
		
		Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
		//set ^zjb("EnviaConsulta",7)="7 "_tSC
		Set tSC = tWSSend.SendEvent(StockUpdateMsg,	.pResponse)
		//set ^zjb("EnviaConsulta",8)="8 "_tSC
		//set ^zjb("EnviaConsulta",9)=pResponse
		
		
		//if pResponse.ERPResponse.ErrorDescription '= "" set ^zjb("EnviaConsulta",9)="9 "_pResponse.ERPResponse.ErrorDescription
		If $System.Status.IsError(tSC) Quit
		if (pResponse.ERPResponse.IsError) Quit
		
		set pResponse.LocationCode = $Piece(^CTLOC(+tLoc),"^",1)
		//set ^zjb("Update Stock",2)="2 "_pResponse.LocationCode
		
		set tFinalResponse = ##class(Custom.Nexus.WS.ResponseEvent).%New()
		
		set tSC = ##class(Custom.Nexus.WSEventHandler.StockHandler).StockReGenerator(pResponse,.tFinalResponse)
		kill ^HomologaCodERP(tSession)
		//set ^zjb("Update Stock",3)="3 "_tSC
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			Set resp= $System.Status.GetErrorText(tSC)
		}
		Else
		{
			////set ^zjb("EnviaConsulta",10)="10 "_tSC
			Set tSC = tException.AsStatus()
			Set resp= $System.Status.GetErrorText(tSC)
			//set ^zjb("EnviaConsulta",11)="11 "_tSC
		}
	}
	
	//set ^zjb("EnviaConsulta",12)="12 "_resp
	Quit resp
}

ClassMethod StockReGenerator(pInput As Custom.ERP.WS.s0.StockEvent, Output pResponse As Custom.ERP.WS.s0.Response) As %Status
{
		//set ^zjb("StockERP",2)="2 "_pInput.LocationCode
		Set pResponse=##class(Custom.ERP.Response).%New()
        //Set pResponse.OriginatingSystemCode="TRAKCARE"
    	//Set pResponse.SpecificationCode="CLXX"
    	//Set pResponse.RecordedDateTime=$ZDateTime($H,3)
    	//Set pResponse.SendingFacilityCode="000"
        
        
	Try
	{
		Set tSC = $$$OK
		Set tLocalCode = pInput.LocationCode
		Set tLocalId = ##class(web.CTLoc).GetIdFromCodeDescriptionHosp(tLocalCode)
		//Set tTimeTag = $Replace($h,",","")
		set tTimeTag = $p($h,",",2)
		//set ^zjb("StockERP",3)="3 "_tTimeTag
		
		If (tLocalId'="")
		{	
			Set tItemsCount = pInput.Items.Count()
			//set ^zjb("StockERP",4)="4 "_tItemsCount
			
			For tItemNum = 1:1:tItemsCount
			{   set tItemCodei = pInput.Items.GetAt(tItemNum).StockItemCode
			
				//set ^zjb("StockERP",5)="5 "_tLocalId_" item "_pInput.Items.GetAt(tItemNum).StockItemCode
				Set tSC = ..StockItemReGen(tLocalId, pInput.Items.GetAt(tItemNum),tTimeTag)
			}
		
		}
	}
	Catch (tException)
    {
        Set tSC = tException.AsStatus()
    }
    
    If $System.Status.IsError(tSC)
    {
        Set pResponse.ErrorDescription=$System.Status.GetErrorText(tSC)
        Set pResponse.IsError=1
    }
    else
    {
	    Set pResponse.IsError=0
    }
    Quit tSC
}

ClassMethod StockItemReGen(pLocalId As %String, pInputItem As Custom.ERP.WS.s0.StockEvent, pTimeTag As %String) As %Status
{
	Set tSC = $$$OK
	Try{
		Set tItemCode = pInputItem.StockItemCode
		Set tItemID = ##class(web.INCItm).GetIdFromCodeOrDescription(tItemCode)
		If (tItemID'=""){
			Set tItemLocId = ""
			&SQL(select INCIL_RowId into :tItemLocId from SQLUser.INC_ItmLoc where INCIL_INCI_ParRef = :tItemID and INCIL_CTLOC_DR = :pLocalId)
			If (tItemLocId=""){
				&SQL(Insert into SQLUser.INC_ItmLoc (INCIL_INCI_ParRef, INCIL_CTLOC_DR,INCIL_DateFrom) values (:tItemID,:pLocalId,CURRENT_DATE))
				If SQLCODE 
				{
					set ^zjb("StockERP",6)="6 "_SQLCODE
				}
				Set tItemLocId = %ROWID
				//set ^zjb("StockERP",7)="7 "_tItemLocId
			}
			//set ^zjb("StockERP",8)="8 "_tItemLocId_" pInputItem.BatchNumber "_pInputItem.BatchNumber
			set tItemBatchCode = ""
			set tItemBatchDate = ""
			if pInputItem.BatchNumber '=""
			{   
				//set ^zjb("StockERP",9)="9 "
				if pInputItem.SerialNumber'=""
				{
					Set tItemBatchCode = pInputItem.BatchNumber_";"_pInputItem.SerialNumber
				}
				else
				{
					Set tItemBatchCode = pInputItem.BatchNumber
				}	
			}
			//set ^zjb("StockERP",10)="10 "
			if pInputItem.ExpiryDate '=""
			{ 
				Set tItemBatchDate = $zdh(pInputItem.ExpiryDate,8)
			}
			//set ^zjb("StockERP",11)="11 "
			Set tItemBatchID = ""
			
			if (tItemBatchCode'="") && (tItemBatchDate'="")
			{ 
				&SQL(select INCIB_RowId into :tItemBatchID from SQLUser.INC_ItmBat where INCIB_INCI_ParRef = :tItemID and INCIB_No = :tItemBatchCode and INCIB_ExpDate = :tItemBatchDate)
			}
			else
			{
				&SQL(select INCIB_RowId into :tItemBatchID from SQLUser.INC_ItmBat where INCIB_INCI_ParRef = :tItemID and INCIB_No is null and INCIB_ExpDate is null)
				
			}
			
			//set ^zjb("StockERP",12)="12 "_tItemBatchCode_" 2 "_tItemBatchDate_" 3 "_tItemBatchID_" SQLCODE "_SQLCODE
			If SQLCODE = 100
				{
					set tItemBatchID = ""
					//set ^zjb("StockERP",13)="13 "_SQLCODE_" tItemBatchID "_tItemBatchID
					}
					
			//set ^zjb("StockERP",14)="14 "_tItemBatchID
			If (tItemBatchID=""){
				
				
				&SQL(Insert into SQLUser.INC_ItmBat (INCIB_INCI_ParRef, INCIB_No, INCIB_ExpDate, INCIB_ExpTime) Values (:tItemID, :tItemBatchCode, :tItemBatchDate, :pTimeTag))
				If SQLCODE 
				{
					//set ^zjb("StockERP",15)="15 "_SQLCODE
					}
					 
				
				Set tItemBatchID = %ROWID
				
			}else{
				
				//set ^zjb("StockERP",16)="16 "_tItemBatchID
				&SQL(Update SQLUser.INC_ItmBat Set INCIB_ExpTime = :pTimeTag where INCIB_RowId = :tItemBatchID)
			    	If SQLCODE 
				{
					set ^zjb("StockERP",17)="17 "_SQLCODE
					}
			}
			Set tItemBatchQty = pInputItem.Quantity
			Set tINCLBRowId = ""
			&SQL(Select INCLB_RowId into :tINCLBRowId from SQLUser.INC_ItmLcBt where INCLB_INCIL_ParRef = :tItemLocId and INCLB_INCIB_DR = :tItemBatchID)
			If (tINCLBRowId'=""){
				&SQL(Update SQLUser.INC_ItmLcBt Set INCLB_PhyQty = :tItemBatchQty, INCLB_DirtyQty = null where INCLB_RowId = :tINCLBRowId)
				If SQLCODE 
				{
					set ^zjb("StockERP",18)="18 "_SQLCODE
					}
				
				
			}Else{
				&SQL(Insert into SQLUser.INC_ItmLcBt (INCLB_INCIL_ParRef, INCLB_INCIB_DR, INCLB_PhyQty) Values (:tItemLocId, :tItemBatchID, :tItemBatchQty))
				If SQLCODE 
				{
					set ^zjb("StockERP",19)="19 "_SQLCODE
					}
				
			}
			/// Limpieza de Series 
			/// Se debe poder mejorar esto ...
			&SQL(Update SQLUser.INC_ItmLcBt Set INCLB_PhyQty = 0, INCLB_DirtyQty = null where INCLB_INCIL_ParRef = :tItemLocId and (INCLB_INCIB_DR->INCIB_ExpTime <> :pTimeTag or INCLB_INCIB_DR->INCIB_ExpTime is null))
				If SQLCODE 
				{
					set ^zjb("StockERP",20)="20 "_SQLCODE
					}
			//set ^zjb("StockERP",21)="21 tItemLocId "_tItemLocId
					
			set tSumByLoc=0
			&SQL(select sum(INCLB_PhyQty)
				 into :tSumByLoc
				 from SQLUser.INC_ItmLcBt 
				 where INCLB_INCIL_ParRef = :tItemLocId)
			
			//set ^zjb("StockERP",21)="21 tItemLocId "_tItemLocId_" tSumByLoc "_tSumByLoc
			
			set tTimeUpdateStockFromERP = $h
			&SQL(update %NOLOCK %NOTRIGGER SQLUser.INC_ItmLoc
			     set INCIL_LogQty = :tSumByLoc,
			         INCIL_FreeStorageBin = :tTimeUpdateStockFromERP
				 where INCIL_RowId = :tItemLocId
				 )
				 
		}
		else{
			//TODO: Log Error al menos item de Stock debe existir 
		}
	}Catch err {
		Set tSC = $System.Status.DisplayError(err)
	}
	Quit tSC
}

ClassMethod StockAdministrationToERP(OrdExecID, tranType, batchID, quantityTaken, patientID, OrderItemId = "") As %Status
{
	Set tSC = $System.Status.OK()
	
	
	Try{
			If batchID="" Quit
			If tranType="" Quit
			If quantityTaken="" Quit
			If patientID="" Quit
			If +quantityTaken=0 Quit
			If OrderItemId = "" Quit
			
			set ObjOrdExecution = ##class(User.OEOrdExec).%OpenId(OrdExecID)
			set tQtyAdministrated = ObjOrdExecution.OEOREQtyAdmin
			set tOrdExecID = OrdExecID
			
			&sql(select sum(ISNULL(DSP_Qty,0)-ISNULL(DSP_ReturnQty,0))
			     into :tQtyDispensed
				 from sqluser.OE_Dispensing 
				 where DSP_OEORE_ParRef = :tOrdExecID
				 and DSP_Status in ('P','C')
				 ) 
			//set ^zjb("StockAdm",20)= "20 Qty Dispensed "_tQtyDispensed
				 
			if (tQtyDispensed '= "") && (tQtyDispensed '= 0)
			{
				set quantityTaken = tQtyDispensed
			}
			//set ^zjb("StockAdm",21)= "21 Qty Dispensed "_quantityTaken
			
			if (tQtyAdministrated = "") || (tQtyAdministrated=0)
			{
			
				set ObjOrdItem = ##class(User.OEOrdItem).%OpenId(OrderItemId)
			
				//set ^zjb("StockAdm",2)= "OrderItemId "_OrderItemId
			
				Set RecLocID = ObjOrdItem.OEORIRecDepDR.%Id()
				Set OrdLocID = ObjOrdItem.OEORIOrdDeptDR.%Id()
				Set tNroReceta = ObjOrdItem.OEORIPrescNo
				Set tNroEpisodio = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				Set tBedNumber = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
				set PAADMPAPMIDR = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
						
				Set tPatientName = tFicha_"/"_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			
				If $g(RecLocID) = "" 
				{
					Set tSC = $System.Status.Error(5001,"Dispatching Location is null")
					Quit
				}
			
				//Local Receptor
				Set RecLocCode   = $p(^CTLOC(RecLocID),"^",1)
				Set RecLocCodeERP   = $p(^CTLOC(RecLocID),"^",77)
				Set RecHospID 	 = $p(^CTLOC(RecLocID),"^",22)
				Set RecHospCode  = $p(^CT("HOSP",RecHospID),"^",1)
			
				//Local Solicitante Unidad Temporal
				Set SolLocCode = $p(^CTLOC(OrdLocID),"^",1)
			
			
			
				//set ^zjb("StockAdm",3)= "RecLocCode "_RecLocCode
			
				Set ObjAdministration = ##class(Custom.ERP.StockEvent).%New()
				Set ObjAdministration.MovementCode = "S004"
				Set ObjAdministration.CostCenter = "A0ACDAAS01"
				Set ObjAdministration.LogisticLocation = $p(RecLocCodeERP,";",1)
				Set ObjAdministration.LocationCode = $p(RecLocCodeERP,";",2)
				Set ObjAdministration.CostCenter = SolLocCode
				Set ObjAdministration.DocumentNo = tNroReceta
				Set ObjAdministration.Episode = tNroEpisodio
				Set ObjAdministration.PatientLocation = tBedNumber
				Set ObjAdministration.PatientName = tPatientName 
			
			
				//set ^zjb("StockAdm",4)= "batchID "_batchID
				//////Items/////
			
				set tItemCode = ObjOrdItem.OEORIItmMastDR.ARCIMCode
				set tItemDesc = ObjOrdItem.OEORIItmMastDR.ARCIMDesc
			
				set ObjBatch = ##class(User.INCItmLcBt).%OpenId(batchID)
			
				//set ^zjb("StockAdm",5)= "5 "_batchID
				Set item = ##class(Custom.ERP.StockItems).%New()
	    		Set item.Quantity = quantityTaken
	    		Set item.StockItemCode = $piece(ObjBatch.INCLBINCIBDR.INCIBNo,";",2)																		               
				Set item.StockItemDesc = tItemDesc
				Set item.BatchNumber   = $piece(ObjBatch.INCLBINCIBDR.INCIBNo,";",1)
				Set item.ExpiryDate    = $zdate(ObjBatch.INCLBINCIBDR.INCIBExpDate,8)
			
				//set ^zjb("StockAdm",6) = "Qty "_item.Quantity_" Code "_item.StockItemCode_" Desc "_item.StockItemDesc_" Batch "_item.BatchNumber_" Fecha "_item.ExpiryDate
				Do ObjAdministration.Items.Insert(item)
		
		
				////////////////// Envío de mensaje ///////////////////////
			
				Set pResponse = ##class(Custom.ERP.Response).%New()
				Set tWSSend = ##class(Custom.ERP.ServiceSoap).%New()
			
				Set tSC = tWSSend.WSSecurityLogin("Integration","NeorisSidra") //"ikae7She0v")
				If $System.Status.IsError(tSC) Quit
				Set tSC = tWSSend.SendEvent(ObjAdministration,	.pResponse)
			
			
				///////////////////////////////////////////////////////////
			
			
				//set ^zjb("StockAdm",9)= "9 "_tSC
			}
			
	}Catch(tException){
		Set tSC = tException.AsStatus()
		W $System.Status.GetErrorText(tSC)
		//set ^zjb("StockAdm",8)= "8 "_tSC
	}
	
	Quit tSC
}

ClassMethod StockReturnToERP(OrdIDs) As %Status
{
	Set tSC = $System.Status.OK()
	Try{
			for oid=1:1:$length(OrderIDs,"^") 
		
			{
				set ord=$piece(OrderIDs,"^",oid)
			
				&sql(declare ItemsReurned Cursor for  
					select DSP_INCLB_DR->INCLB_INCIB_DR,sum(DSP_INCLB_DR->INCLB_PhyQty)
					into :tbatchID, :tquantityTaken
					from sqluser.OE_Dispensing
					where DSP_OEORE_ParRef->OEORE_OEORI_ParRef = :ord
					group by DSP_INCLB_DR->INCLB_INCIB_DR)
				
				
				if oid = 1
				{
					set ObjOrdItem = ##class(User.OEOrdItem).%OpenId(ord)
				
					Set RecLocID = ObjOrdItem.OEORIRecDepDR.%Id()
					Set OrdLocID = ObjOrdItem.OEORIOrdDeptDR.%Id()
					Set tNroReceta = ObjOrdItem.OEORIPrescNo
					Set tNroEpisodio = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
					Set tBedNumber = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
					
					set PAADMPAPMIDR = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}
					
					Set tPatientName = tFicha_"/"_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			
					If $g(RecLocID) = "" 
					{
						Set tSC = $System.Status.Error(5001,"Dispatching Location is null")
						Quit
					}
			
					//Local Receptor
					Set RecLocCode   = $p(^CTLOC(RecLocID),"^",1)
					Set RecLocCodeERP   = $p(^CTLOC(RecLocID),"^",55)
					Set RecHospID 	 = $p(^CTLOC(RecLocID),"^",22)
					Set RecHospCode  = $p(^CT("HOSP",RecHospID),"^",1)
			
					//Local Solicitante Unidad Temporal
					Set SolLocCode = $p(^CTLOC(OrdLocID),"^",55)
				
				
					Set ObjAdministration = ##class(Custom.ERP.StockEvent).%New()
					Set ObjAdministration.MovementCode = "S005"
					//Set ObjAdministration.CostCenter = "A0ACDAAS01"
					Set ObjAdministration.LogisticLocation = $p(RecLocCodeERP,";",1)
					Set ObjAdministration.LocationCode = $p(RecLocCodeERP,";",2)
					Set ObjAdministration.CostCenter = SolLocCode
					Set ObjAdministration.DocumentNo = tNroReceta
					Set ObjAdministration.Episode = tNroEpisodio
					Set ObjAdministration.PatientLocation = tBedNumber
					Set ObjAdministration.PatientName = tPatientName 
				
				}
			
			
				&SQL(Open ItemsReurned)
				&SQL(Fetch ItemsReurned)
				while(SQLCODE=0)
				{
					set tItemCode = ObjOrdItem.OEORIItmMastDR.ARCIMCode
					set tItemDesc = ObjOrdItem.OEORIItmMastDR.ARCIMDesc
			
					set ObjBatch = ##class(User.INCItmLcBt).%OpenId(tbatchID)
				
					//set ^zjb("StockReturnToERP",5)= "5 "_batchID
					Set item = ##class(Custom.ERP.StockItems).%New()
	    			Set item.Quantity = tquantityTaken
	    			Set item.StockItemCode = $piece(ObjBatch.INCLBINCIBDR.INCIBNo,";",2)																		               
					Set item.StockItemDesc = tItemDesc
					Set item.BatchNumber   = $piece(ObjBatch.INCLBINCIBDR.INCIBNo,";",1)
					Set item.ExpiryDate    = $zdate(ObjBatch.INCLBINCIBDR.INCIBExpDate,8)
			
					//set ^zjb("StockReturnToERP",6) = "Qty "_item.Quantity_" Code "_item.StockItemCode_" Desc "_item.StockItemDesc_" Batch "_item.BatchNumber_" Fecha "_item.ExpiryDate
				
					Do ObjAdministration.Items.Insert(item)	
				
					&SQL(Fetch ItemsReurned)
				}
				&SQL(Close ItemsReurned)
			
			}	
			
			////////////////// Envío de mensaje ///////////////////////
			
			Set pResponse = ##class(Custom.ERP.Response).%New()
			Set tWSSend = ##class(Custom.ERP.ServiceSoap).%New()
			Set tSC = tWSSend.WSSecurityLogin("Integration","NeorisSidra") //"ikae7She0v")
			If $System.Status.IsError(tSC) Quit
			Set tSC = tWSSend.SendEvent(ObjAdministration,	.pResponse)
			
			
			///////////////////////////////////////////////////////////
			
			
			//set ^zjb("StockReturnToERP",9)= "9 "_tSC		
		}
	Catch(tException){
		Set tSC = tException.AsStatus()
		W $System.Status.GetErrorText(tSC)
		//set ^zjb("StockAdm",8)= "8 "_tSC
	}
	Quit tSC
}

ClassMethod StockPacked(pOrderIDs, pEpisodeID) As %String
{
	//set ^zjb("Reserva",0)="0 "_$Get(%request.Data("TFORM",1)) 
	if ($Get(%request.Data("TFORM",1))="Pharmacy.Presc.Edit")
	{	
		Try
		{
			set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
			//Salir si no está activa la integracion
			if 'tIntegrationOn Quit		
			
			//set ^zjb("Reserva",1)="1 pOrderIDs "_pOrderIDs_" pEpisodeID "_pEpisodeID
			if (pOrderIDs'=""){
			Set lOrderIDs = $LFS(pOrderIDs,"^")
			Set (tQty, tINCIBExpDate, tINCIBNo, tINCICode, tINCILCTLOCDR) = ""
			Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set StockUpdateMsg.MovementCode = "S002"
			Set StockUpdateMsg.User = $g(%session.Data("LOGON.USERCODE"))
			Set StockUpdateMsg.DocumentNo = $Get(%request.Data("OLDPrescNo",1))
			
			//set ^zjb("Reserva","9")="9"
			Set tObjAdm = ##class(User.PAAdm).%OpenId(pEpisodeID)
			Set StockUpdateMsg.Episode = tObjAdm.PAADMADMNo
			Set StockUpdateMsg.PatientLocation = tObjAdm.PAADMCurrentBedDR.BEDCode
			
			
			Set tLocal = $Get(%request.Data("Loc",1))
			Set tObjLocal = ##class(User.CTLoc).%OpenId(tLocal)
			//Set StockUpdateMsg.LogisticLocation = tObjLocal.CTLOCExternalViewerLink
			//set ^zjb("Reserva","91")="91 tObjLocal "
			Set StockUpdateMsg.LocationCode = tObjLocal.CTLOCPagerNo
			Set StockUpdateMsg.FacilityCode = "1000" 
			//tObjLocal.CTLOCHospitalDR.HOSPFacilityId
			
			//set ^zjb("Reserva","92")="92 "_StockUpdateMsg.LocationCode
			
			Set tPatientID = $Get(%request.Data("PatientID",1))
			
			set PAADMPAPMIDR = tPatientID
			set (tRtMastId,tFicha) = ""
			set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
			if tRtMastId '= ""
			{
				set tFicha = $piece(^RT(tRtMastId),"^",1)
			}
			
			Set tObjPatient = ##class(User.PAPerson).%OpenId(tPatientID)
			Set StockUpdateMsg.PatientName = tFicha_"/"_tObjPatient.PAPERID_"/"_tObjPatient.PAPERName2_" "_tObjPatient.PAPERName
			
			//set ^zjb("Reserva","93")="93"
			
			//Set StockUpdateMsg.CostCenter = "A0ACDAAS01"
			
			//set ^zjb("Reserva","1.1")="1.1 Loc "_StockUpdateMsg.LocationCode_" Paciente "_ StockUpdateMsg.PatientName
			
			&sql(select max(DSP_Time)
			     into :tLastTime
				 from sqluser.OE_Dispensing 
				 where DSP_OEORE_ParRef->OEORE_OEORI_ParRef %inlist :lOrderIDs and DSP_Status in ('P')
			  	 and DSP_ReturnQty is null)
			
			//set ^zjb("Reserva","2")="2 tLastTime "_tLastTime
			
			&SQL(Declare Paking Cursor For
			select sum(DSP_Qty), 
			DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
			DSP_INCLB_DR->INCLB_INCIB_DR, 
			DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
			DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,
			DSP_OEORE_ParRef->OEORE_OEORI_ParRef
			into :tQty, :tINCIBExpDate, :tINCIBNo, :tINCIId, :tINCILCTLOCDR, :tOrderId
			from sqluser.OE_Dispensing 
			where DSP_OEORE_ParRef->OEORE_OEORI_ParRef %inlist :lOrderIDs and DSP_Status in ('P')
			  and DSP_ReturnQty is null
			  and DSP_Time = :tLastTime
			group by DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
			DSP_INCLB_DR->INCLB_INCIB_DR, 
			DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
			DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,DSP_OEORE_ParRef->OEORE_OEORI_ParRef)
			
				//set ^zjb("Reserva","3")= "3 "_SQLCODE
			&SQL(Open Paking)
				//set ^zjb("Reserva","4")= "4 "_SQLCODE
			&SQL(Fetch Paking)
				//set ^zjb("Reserva","5")= "5 "_SQLCODE
			while(SQLCODE=0){
				
				//set ^zjb("Reserva",tINCIId,3)="3 "_tINCIId
				
				
				Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				

				set tObjBatch = ##class(User.INCItmBat).%OpenId(tINCIBNo)
				set tBatchNumber = tObjBatch.INCIBNo
				if tBatchNumber '= ""
				{
					Set StockItem.BatchNumber = $p(tBatchNumber,";",1)
				}
				if tINCIBExpDate '= ""
				{
					Set StockItem.ExpiryDate = $zd(tINCIBExpDate,8)
				}
				
				Set LocCode = $Piece(^CTLOC(tINCILCTLOCDR),"^",1)
				Set StockItem.Quantity = tQty
				
				
				///Codigo Item
				set tCodERP = ..GetItemCodeERP(tINCIId)
				
				Set StockItem.StockItemCode = tCodERP
				
				//Incorporar el Order Item relacionado por si hay Error rescatar
				Set StockItem.SerialNumber = tOrderId
				
				Do StockUpdateMsg.Items.Insert(StockItem)
				
				&SQL(Fetch Paking)
			}
			&SQL(Close Paking)
			
			
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			set tWSSend.Timeout = 300
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("EnviaConsulta",6)="6 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			//set ^zjb("EnviaConsulta",7)="7 "_tSC
			Set tSC = tWSSend.SendEvent(StockUpdateMsg,	.pResponse)
		
			//set ^zjb("EnviaConsulta",8)="8 "_tSC
			//if pResponse.ERPResponse.ErrorDescription '= "" set ^zjb("EnviaConsulta",9)="9 "_pResponse.ERPResponse.ErrorDescription
			
			//Sólo para Test, Borrar
			//set pResponse.ERPResponse.IsError=0
			
			if pResponse.ERPResponse.IsError
			{
				//set ^zjb("Error",1)="1 "_StockUpdateMsg.DocumentNo
				//Generar Traza para asociar al item de orden en caso de error y volver a enviar
				for i=1:1:StockUpdateMsg.Items.Count()
				{	
					set tOrderId = ""
					set tOrderId = StockUpdateMsg.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tTextError = ""
						if pResponse.ERPResponse.IsError '= "" set tTextError = pResponse.ERPResponse.ErrorDescription
					
						set tTextToResend = ""
						 //1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
						//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
						set tTextToResend = StockUpdateMsg.MovementCode_"(;)"_StockUpdateMsg.DocumentNo_"(;)"_StockUpdateMsg.LocationCode_"(;)"_StockUpdateMsg.FacilityCode_"(;)"_StockUpdateMsg.Items.GetAt(i).StockItemCode_"(;)"_StockUpdateMsg.Items.GetAt(i).Quantity
						if StockUpdateMsg.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_StockUpdateMsg.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
						if StockUpdateMsg.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_StockUpdateMsg.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
						set tTextToResend = tTextToResend_";"_$p($h,",",1)_";"_$p($h,",",2)_";"_$g(%session.Data("LOGON.USERCODE"))_"(;)"_$extract(tTextError,1,55)
						
						
						set tObjOrder = ""
						set tObjOrder = ##class(User.OEOrdItem).%OpenId(tOrderId)
						if $IsObject(tObjOrder)
						{
							
							set tEstado = ""
							set tDescripcion = ""
							
							set tText3 = tObjOrder.OEORIText3
							set tDispDesc = $piece(tText3,"-DIS-",2)
							set tDescripcion = tTextToResend_"-DIS-"_tDispDesc
														
							
							set tText4 = tObjOrder.OEORIText4
							set tDispEstado = $piece(tText4,"-DIS-",2)
							set tEstado = "ERR"_"-DIS-"_tDispEstado
							
							
							set tObjOrder.OEORIText3 = tDescripcion
							set tObjOrder.OEORIText4 = tEstado
							
							do tObjOrder.%Save()
							
							
						}
					
					}			
				}	
				
			}
			else
			{
				//set ^zjb("NoError",1)="1 "_StockUpdateMsg.DocumentNo
				for i=1:1:StockUpdateMsg.Items.Count()
				{
					set tOrderId = ""
					set tOrderId = StockUpdateMsg.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tObjOrder = ""
						set tObjOrder = ##class(User.OEOrdItem).%OpenId(tOrderId)
						
						set tEstado = ""
						set tDescripcion = ""
						
						set tDescripcion = StockUpdateMsg.DocumentNo_";"_$g(%session.Data("LOGON.USERCODE"))_";"_$p($h,",",1)_";"_$p($h,",",2)
							
						set tText3 = tObjOrder.OEORIText3
						set tDispDesc = $piece(tText3,"-DIS-",2)
						set tDescripcion = tTextToResend_"-DIS-"_tDispDesc
														
							
						set tText4 = tObjOrder.OEORIText4
						set tDispEstado = $piece(tText4,"-DIS-",2)
						set tEstado = "E"_"-DIS-"_tDispEstado
							
							
						set tObjOrder.OEORIText3 = tDescripcion
						set tObjOrder.OEORIText4 = tEstado
							
						do tObjOrder.%Save()
					}			
				}	
				
			}
		
		}
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			
		}
		Else
		{
			//set ^zjb("Reserva",6)="6 "_tSC
			Set tSC =  tException.AsStatus()
			//set ^zjb("Reserva",7)="7 "_tSC
		}
	}
	//set ^zjb("Reserva",8)="8 "_tSC
	Quit 1
}
}

ClassMethod StockPackedERP() As %String
{
	Try
	{
		//set ^zjb("NewPack",1)="1"
		set tgroupId = ""
		set tSC = $$$OK
		if ($Get(%request.Data("TFORM",1))="Pharmacy.Presc.Edit")
		{
			set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
			//Salir si no está activa la integracion
			
		
			Set tLocal = $Get(%request.Data("Loc",1))
			Set tObjLocal = ##class(User.CTLoc).%OpenId(tLocal)
			if tObjLocal.CTLOCPagerNo = "" Quit
			
				
			set tHeaderMessage = 1
			set ind = 1
			
			set tgroupId = $i(^HMSDispensacionGroup)
			
			while $get(%request.Data("RowIDz"_ind,1)) '= ""
			{
				if $get(%request.Data("ActionOKz"_ind,1))'= "on"
				{
					set ind = ind+1
					continue
				}
				
				//set ^zjb("NewPack",1)="1"
				//OrderItem
				set (tOrderId,tObjOrder) = ""
				set tOrderId = $get(%request.Data("RowIDz"_ind,1))
				if tOrderId = ""
				{ 
					set ind = ind+1
					continue
				}
				
				set tObjOrder = ##class(User.OEOrdItem).%OpenId(tOrderId)
				
				if '$IsObject(tObjOrder)
				{
					set ind = ind+1
					continue
				}
				
				//set ^zjb("NewPack","Row",tOrderId)="1"
				
				set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
				set tObjToInsert.OrderGroupId = tgroupId
				set tObjToInsert.OrderRef = tObjOrder
				
				//Cantidad
				set tQty = ""
				set tQty = $get(%request.Data("batchtakenz"_ind,1))
				set tObjToInsert.Cantidad = tQty
				
				//Tipo Movimiento 
				set tObjToInsert.TipoMovimiento = "S002"
				
				//Locales 
				set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
				Set tLocal = $Get(%request.Data("Loc",1))
				if tLocal '= "" Set tObjLocal = ##class(User.CTLoc).%OpenId(tLocal)
				if $IsObject(tObjLocal)
				{
					Set tLocalERP = tObjLocal.CTLOCPagerNo
					if $IsObject(tObjLocal.CTLOCGLCCCDR)
					{
						set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
					}
					
					set tObjToInsert.LocalTrak = tObjLocal
					set tObjToInsert.LocalCodeERP = tLocalERP
					set tObjToInsert.CentroCosto = tCentroCosto
					set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
				}
				
				//Nro Documento
				set (NroDoumento)=""
				
				set tNroDocumento = tObjOrder.OEORIPrescNo
				if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
				set tObjToInsert.NroDocumento = tNroDocumento
				
				//Usuario
				set tObjToInsert.Usuario = $g(%session.Data("LOGON.USERCODE"))
				
				
				//Episodio
				set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
				//Paciente
				set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
				if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
				{
					set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}
				
					Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
				}

				
				///Datos Item
				set (tBatchNumber,tINCIBExpDate,tItemLcBt,tCodERP) = ""
				
				set tItemLcBt = $get(%request.Data("batchidz"_ind,1))
				if tItemLcBt '= ""
				{
					set tBatchRowId = ""
					set tBatchRowId = $piece(^INCI($piece(tItemLcBt,"||",1),"IL",$piece(tItemLcBt,"||",2),"LB",$piece(tItemLcBt,"||",3)),"^",1)
				
					if tBatchRowId '= ""
					{
						set tBatchNumber = $piece(^INCI($piece(tBatchRowId,"||",1),"IB",$piece(tBatchRowId,"||",2)),"^",1)
						set tINCIBExpDate = $piece(^INCI($piece(tBatchRowId,"||",1),"IB",$piece(tBatchRowId,"||",2)),"^",2)
					
					}	
				
					if tBatchNumber '= ""
					{
						set tBatchNumber = $p(tBatchNumber,";",1)
					}
					if tINCIBExpDate '= ""
					{
						Set tINCIBExpDate = $zd(tINCIBExpDate,8)
					}
				
				}
			
				set tINCIId = ""
				set tINCIId = $get(%request.Data("INCIz"_ind,1))
			
				if tINCIId '= ""
				{
					set tCodERP = ..GetItemCodeERP(tINCIId)
			
				}	
			
				set tObjToInsert.CodigoERP = tCodERP
				set tObjToInsert.Lote = tBatchNumber
				set tObjToInsert.FecVencimiento = tINCIBExpDate
				
				set tObjToInsert.CantIntentos = 0
				set tObjToInsert.EstadoEnvio = "Ingresado"
				set tObjToInsert.ProcIngreso = "StockPackedERP-Pharmacy.Presc.Edit"
				
				set tSC = tObjToInsert.%Save()
				
				set ind = ind+1
						
			}
			
		}	
		
		set tResp = ..EnvioDispToERP("Grupo", "", tgroupId,$g(%session.Data("LOGON.USERCODE")))
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			
		}
		Else
		{
			
			Set tSC =  tException.AsStatus()
			
		}
	}
	//set ^zjb("NewPack","Error")= tSC
	
	Quit 1
	
	/* Codigo Anterior
	Try
	{
		if ($Get(%request.Data("TFORM",1))="Pharmacy.Presc.Edit")
		{
			set ^zjb("StockPaked",1) = 0
			set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
			//Salir si no está activa la integracion
			if 'tIntegrationOn Quit
		
			Set tLocal = $Get(%request.Data("Loc",1))
			set ^zjb("StockPaked",2) = 2_tLocal
			Set tObjLocal = ##class(User.CTLoc).%OpenId(tLocal)
			if tObjLocal.CTLOCPagerNo = "" Quit
			
			set ^zjb("StockPaked",3) = 3_tLocal_" sa code "_tObjLocal.CTLOCPagerNo
				
			set tHeaderMessage = 1
			set ind = 1
			while $get(%request.Data("RowIDz"_ind,1)) '= ""
			{
				if $get(%request.Data("ActionOKz"_ind,1))'= "on"
				{
					set ind = ind+1
					continue
				}
				
				////Add
				set tQty = ""
				set tQty = $get(%request.Data("batchtakenz"_ind,1))
				
				set tIdDispensing = $get(%request.Data("RowIDz"_ind,1))
				if $get(tIdDispensing)'="" set ^DispensingIntegrationHMS(tIdDispensing,"StockPackedERP","S002",$h) = "Cant: "_tQty_" Fecha: "_$zd($p($h,",",1),4)_" Hora: "_$zt($p($h,",",2),2)
				////Add
						
				if tHeaderMessage = 1
				{
					Set (tQty, tINCIBExpDate, tINCIBNo, tINCICode, tINCILCTLOCDR,tEpisodeID) = ""
					Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					Set StockUpdateMsg.MovementCode = "S002"
					Set StockUpdateMsg.User = $g(%session.Data("LOGON.USERCODE"))
					Set StockUpdateMsg.DocumentNo = $replace($Get(%request.Data("OLDPrescNo",1)),"^","-")
				
					set tEpisodeID = $Get(%request.Data("EpisodeIDz"_ind,1))	
				
					Set tObjAdm = ##class(User.PAAdm).%OpenId(tEpisodeID)
					Set StockUpdateMsg.Episode = tObjAdm.PAADMADMNo
					Set StockUpdateMsg.PatientLocation = tObjAdm.PAADMCurrentBedDR.BEDCode
				
					Set tLocal = $Get(%request.Data("Loc",1))
					Set tObjLocal = ##class(User.CTLoc).%OpenId(tLocal)
					Set StockUpdateMsg.LocationCode = tObjLocal.CTLOCPagerNo
					Set StockUpdateMsg.CostCenter = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
					Set StockUpdateMsg.FacilityCode = "1000" 
				
					Set tPatientID = $Get(%request.Data("PatientID",1))
					
					set PAADMPAPMIDR = tPatientID
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}
					
					Set tObjPatient = ##class(User.PAPerson).%OpenId(tPatientID)
					Set StockUpdateMsg.PatientName = tFicha_"/"_tObjPatient.PAPERID_"/"_tObjPatient.PAPERName2_" "_tObjPatient.PAPERName
				}
			
			
				Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
			
				set tBatchNumber = "",tINCIBExpDate = ""
				set tItemLcBt = ""
				set tItemLcBt = $get(%request.Data("batchidz"_ind,1))
				if tItemLcBt '= ""
				{
					set tBatchRowId = ""
					set tBatchRowId = $piece(^INCI($piece(tItemLcBt,"||",1),"IL",$piece(tItemLcBt,"||",2),"LB",$piece(tItemLcBt,"||",3)),"^",1)
				
					if tBatchRowId '= ""
					{
						set tBatchNumber = $piece(^INCI($piece(tBatchRowId,"||",1),"IB",$piece(tBatchRowId,"||",2)),"^",1)
						set tINCIBExpDate = $piece(^INCI($piece(tBatchRowId,"||",1),"IB",$piece(tBatchRowId,"||",2)),"^",2)
					
					}	
				
					if tBatchNumber '= ""
					{
						Set StockItem.BatchNumber = $p(tBatchNumber,";",1)
					}
					if tINCIBExpDate '= ""
					{
						Set StockItem.ExpiryDate = $zd(tINCIBExpDate,8)
					}
				
				}
			
				set tINCIId = ""
				set tINCIId = $get(%request.Data("INCIz"_ind,1))
			
				if tINCIId = "" set ind=ind+1 continue
				///Codigo Item
				set tCodERP = ..GetItemCodeERP(tINCIId)
			
				if tCodERP = "" set ind=ind+1 continue
			
				Set StockItem.StockItemCode = tCodERP
				
				//Incorporar el Order Item relacionado por si hay Error rescatar
				set tOrderId = ""
				set tOrderId = $get(%request.Data("RowIDz"_ind,1))
			
				if tOrderId = "" set ind=ind+1 continue
			
				Set StockItem.SerialNumber = tOrderId
				
				set tQty = ""
				set tQty = $get(%request.Data("batchtakenz"_ind,1))
				if tQty = "" set ind = ind+1 continue
				
				Set StockItem.Quantity = tQty
				Do StockUpdateMsg.Items.Insert(StockItem)
			
				set tHeaderMessage = tHeaderMessage +1
				set ind = ind+1
						
			}
			
			if StockUpdateMsg.Items.Count() = 0 quit
			
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			set tWSSend.Timeout = 300
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("EnviaConsulta",6)="6 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			set ^zjb("EnviaConsulta",7)="7 "_tSC
			Set tSC = tWSSend.SendEvent(StockUpdateMsg,	.pResponse)
		
			set ^zjb("EnviaConsulta",8)="8 "_tSC
			if pResponse.ERPResponse.ErrorDescription '= "" set ^zjb("EnviaConsulta",9)="9 "_pResponse.ERPResponse.ErrorDescription
			
			//Sólo para Test, Borrar
			//set pResponse.ERPResponse.IsError=0
			
			if pResponse.ERPResponse.IsError
			{
				set ^zjb("Error",1)="1 "_StockUpdateMsg.DocumentNo
				//Generar Traza para asociar al item de orden en caso de error y volver a enviar
				for i=1:1:StockUpdateMsg.Items.Count()
				{	
					set tOrderId = ""
					set tOrderId = StockUpdateMsg.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tTextError = ""
						if pResponse.ERPResponse.IsError '= "" set tTextError = pResponse.ERPResponse.ErrorDescription
					
						set tTextToResend = ""
						 //1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
						//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
						set tTextToResend = StockUpdateMsg.MovementCode_"(;)"_StockUpdateMsg.DocumentNo_"(;)"_StockUpdateMsg.LocationCode_"(;)"_StockUpdateMsg.FacilityCode_"(;)"_StockUpdateMsg.Items.GetAt(i).StockItemCode_"(;)"_StockUpdateMsg.Items.GetAt(i).Quantity
						if StockUpdateMsg.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_StockUpdateMsg.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
						if StockUpdateMsg.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_StockUpdateMsg.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
						set tTextToResend = tTextToResend_"(;)"_$p($h,",",1)_"(;)"_$p($h,",",2)_"(;)"_$g(%session.Data("LOGON.USERCODE"))_"(;)"_$extract(tTextError,1,55)
						
						//Actualiza estado de Integración
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tTextToResend,"ERR","ERP",tTextError)
						
					
					}			
				}	
				
			}
			else
			{
				set ^zjb("NoError",1)="1 "_StockUpdateMsg.DocumentNo
				for i=1:1:StockUpdateMsg.Items.Count()
				{
					set tOrderId = ""
					set tOrderId = StockUpdateMsg.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tDescripcion = StockUpdateMsg.DocumentNo_";"_$g(%session.Data("LOGON.USERCODE"))_";"_$p($h,",",1)_";"_$p($h,",",2)
						
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tDescripcion,"E","ERP")
						
					}			
				}	
				
			}
		}
		
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			
		}
		Else
		{
			//set ^zjb("Reserva",6)="6 "_tSC
			Set tSC =  tException.AsStatus()
			//set ^zjb("Reserva",7)="7 "_tSC
		}
	}
	set ^zjb("Reserva",8)="8 "_tSC
	Quit 1
	
	*/
}

ClassMethod StockUnPacked() As %String
{
	Try
	{
		set tgroupId = $i(^HMSDispensacionGroup)
		//Retorno por el total
		if ($Get(%request.Data("TFORM",1))="Pharmacy.ReturnAll.Edit")
		{
			set OrderIDs = $Get(%request.Data("OrderIDs",1))				
			if (OrderIDs'="")
			{
				Set lOrderIDs = $LFS(OrderIDs,"^")
				Set (tQty, tINCIBExpDate, tINCIBNo, tINCIId, tINCILCTLOCDR) = ""
				
				&SQL(Declare Return Cursor For
					select sum(ISNULL(DSP_Qty,0))-sum(ISNULL(DSP_ReturnQty,0)), 
					DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
					DSP_INCLB_DR->INCLB_INCIB_DR, 
					DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
					DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,
					DSP_OEORE_ParRef->OEORE_OEORI_ParRef
					into :tQty, :tINCIBExpDate, :tINCIBNo, :tINCIId, :tINCILCTLOCDR, :tOrderId
					from sqluser.OE_Dispensing 
					where DSP_OEORE_ParRef->OEORE_OEORI_ParRef %inlist :lOrderIDs and DSP_Status in ('C')
					and DSP_ReturnQty is null
					and DSP_OEORE_ParRef->OEORE_Order_Status_DR->STAT_SystemAdminStatus = 'NOT'
					group by DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
					DSP_INCLB_DR->INCLB_INCIB_DR, 
					DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
					DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,
					DSP_OEORE_ParRef->OEORE_OEORI_ParRef
					)
					
			
				&SQL(Open Return)
				&SQL(Fetch Return)
				while(SQLCODE=0)
				{	
					////Metodo Nuevo
					if tOrderId '=""
					{
						set tObjOrder = ##class(User.OEOrdItem).%OpenId(tOrderId)
						if '$IsObject(tObjOrder)
						{
							&SQL(Fetch Return)
							continue	
						}
					}
					set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
					set tObjToInsert.OrderGroupId = tgroupId
					set tObjToInsert.OrderRef = tObjOrder
					
					//Cantidad
					set tObjToInsert.Cantidad = tQty
				
					//Tipo Movimiento 
					set tObjToInsert.TipoMovimiento = "S003"
				
					//Locales 
					set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
					
					if $IsObject(tObjOrder.OEORIRecDepDR)
					{
						Set tObjLocal = tObjOrder.OEORIRecDepDR
					}
					
					if $IsObject(tObjLocal)
					{
						Set tLocalERP = tObjLocal.CTLOCPagerNo
						if $IsObject(tObjLocal.CTLOCGLCCCDR)
						{
							set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
						}
					
						set tObjToInsert.LocalTrak = tObjLocal
						set tObjToInsert.LocalCodeERP = tLocalERP
						set tObjToInsert.CentroCosto = tCentroCosto
						set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
					}
				
					//Nro Documento
					set (NroDoumento)=""
					set tNroDocumento = tObjOrder.OEORIPrescNo
					if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
					set tObjToInsert.NroDocumento = tNroDocumento
				
					//Usuario
					set tObjToInsert.Usuario = $g(%session.Data("LOGON.USERCODE"))
				
				
					//Episodio
					set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
					//Paciente
					set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
					if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
					{
						set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
						set (tRtMastId,tFicha) = ""
						set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
						if tRtMastId '= ""
						{
							set tFicha = $piece(^RT(tRtMastId),"^",1)
						}
				
						Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
					}

				
					///Datos Item
					set tCodERP = ""
					if tINCIId '= ""
					{
						set tCodERP = ..GetItemCodeERP(tINCIId)
			
					}	
			
					set tObjToInsert.CodigoERP = tCodERP
					
					set tObjBatch = ##class(User.INCItmBat).%OpenId(tINCIBNo)
					set tBatchNumber = tObjBatch.INCIBNo
					if tBatchNumber '= ""
					{
						set tObjToInsert.Lote = $p(tBatchNumber,";",1)
					}
					if tINCIBExpDate '= ""
					{
						set tObjToInsert.FecVencimiento = $zd(tINCIBExpDate,8)
					}
					
					set tObjToInsert.CantIntentos = 0
					set tObjToInsert.EstadoEnvio = "Ingresado"
					set tObjToInsert.ProcIngreso = "StockUnPacked-Pharmacy.ReturnAll.Edit"
				
					set tSC = tObjToInsert.%Save()
					
					&SQL(Fetch Return)
				}
				&SQL(Close Return)
			}
		}
		
		if ($Get(%request.Data("TFORM",1))="Pharmacy.ReturnPart.Edit")
		{
			set OrderIDs = $Get(%request.Data("OrderIDs",1))	
			//set ^zjb("RetornaPart",1)="1 "_OrderIDs
			
			if (OrderIDs'="")
			{
				Set (tReturnType,tMovementCode)=""
				Set tReturnType = $Get(%request.Data("ReasonForINCReturn",1))
				if tReturnType = "Merma / Faltante"
				{
					Set tMovementCode = "S004"
				}
				else
				{
					Set tMovementCode = "S003"
				}
				
				Set tDescription = $Get(%request.Data("ReasonForRefund",1))
				set ind = 1				
				while $Get(%request.Data("orditmz"_ind,1))'= ""
				{
					
					set tQuantity=$Get(%request.Data("ReturnQtyz"_ind,1))
					
					if tQuantity = "" Set tQuantity=0
								
					if tQuantity > 0
					{
												
						////Metodo Nuevo
						set tOrderId = $Get(%request.Data("orditmz"_ind,1))
						if tOrderId '=""
						{
							set tObjOrder = ##class(User.OEOrdItem).%OpenId(tOrderId)
							if '$IsObject(tObjOrder)
							{
								set ind = ind +1
								continue	
							}
						}
						set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
						set tObjToInsert.OrderGroupId = tgroupId
						set tObjToInsert.OrderRef = tObjOrder
					
						//Cantidad
						set tObjToInsert.Cantidad = tQuantity
				
						//Tipo Movimiento 
						set tObjToInsert.TipoMovimiento = tMovementCode
				
						//Locales 
						set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
					
						if $IsObject(tObjOrder.OEORIRecDepDR)
						{	
							Set tObjLocal = tObjOrder.OEORIRecDepDR
						}
					
						if $IsObject(tObjLocal)
						{
							Set tLocalERP = tObjLocal.CTLOCPagerNo
							if $IsObject(tObjLocal.CTLOCGLCCCDR)
							{
								set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
							}
					
							set tObjToInsert.LocalTrak = tObjLocal
							set tObjToInsert.LocalCodeERP = tLocalERP
							set tObjToInsert.CentroCosto = tCentroCosto
							set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
						}
				
						//Nro Documento
						set (NroDoumento)=""
						set tNroDocumento = tObjOrder.OEORIPrescNo
						if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
						set tObjToInsert.NroDocumento = tNroDocumento
				
						//Usuario
						set tObjToInsert.Usuario = $g(%session.Data("LOGON.USERCODE"))
				
				
						//Episodio
						set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
						//Paciente
						set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
						if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
						{
							set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
							set (tRtMastId,tFicha) = ""
							set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
							if tRtMastId '= ""
							{
								set tFicha = $piece(^RT(tRtMastId),"^",1)
							}
				
							Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
						}

				
						///Datos Item
						set tCodERP = ""
						set tOEORIItmMastDR = tObjOrder.OEORIItmMastDR.%Id()
						set tCodItemMast = tObjOrder.OEORIItmMastDR.ARCIMCode
						
						//Codigo Externo
						set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
						set tLocalHomologacionERP = "SAP"
						if tLocalHomologacionERP '=""
						{
							set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
							set tCodERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
						}
						
						//Si no existe Homologacion se manda el codigo del item
						if tCodERP = "" set tCodERP = tCodItemMast
			
						set tObjToInsert.CodigoERP = tCodERP
					
						
						set tINCIBNo = $Get(%request.Data("BatchIDz"_ind,1))
										
						set tObjBatch = ##class(User.INCItmBat).%OpenId(tINCIBNo)
						set tInci=tObjBatch.INCIBINCIParRef.%Id()
						set tBatchNumber = tObjBatch.INCIBNo
				    	set tINCIBExpDate = tObjBatch.INCIBExpDate
				    
						if tBatchNumber '= ""
						{
							set tObjToInsert.Lote = $p(tBatchNumber,";",1)
						}
						if tINCIBExpDate '= ""
						{
							set tObjToInsert.FecVencimiento = $zd(tINCIBExpDate,8)
						}
					
						set tObjToInsert.CantIntentos = 0
						set tObjToInsert.EstadoEnvio = "Ingresado"
						set tObjToInsert.ProcIngreso = "StockUnPacked-Pharmacy.ReturnPart.Edit"
				
						set tSC = tObjToInsert.%Save()
						
					}
					set ind = ind+1
					
				}
						
			}
				
		}
		
		set tResp = ..EnvioDispToERP("Grupo", "", tgroupId,$g(%session.Data("LOGON.USERCODE")))
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
		}
		Else
		{
			//set ^zjb("Retorna",6)="6 "_tSC
			Set tSC =  tException.AsStatus()
			//set ^zjb("Retorna",7)="6 "_tSC
		}
	}
	
	//set ^zjb("NewUnPack","Error")=tSC
	Quit 1
	
	/* Codigo Anterior
     
    Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	
		
		//Retorno por el total
		if ($Get(%request.Data("TFORM",1))="Pharmacy.ReturnAll.Edit")
		{
			
			set OrderIDs = $Get(%request.Data("OrderIDs",1))	
			//set ^zjb("Retorna",1)="1 "_OrderIDs
			
			if (OrderIDs'="")
			{
				set tOrderItemId = $piece(OrderIDs,"^",1)
			
				Set lOrderIDs = $LFS(OrderIDs,"^")
				
				Set (tQty, tINCIBExpDate, tINCIBNo, tINCIId, tINCILCTLOCDR) = ""
			
				///
				set ObjOrdItem = ##class(User.OEOrdItem).%OpenId(tOrderItemId)
			
				Set RecLocID = ObjOrdItem.OEORIRecDepDR.%Id()
				Set OrdLocID = ObjOrdItem.OEORIOrdDeptDR.%Id()
				Set tNroReceta = ObjOrdItem.OEORIPrescNo
				Set tNroEpisodio = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				Set tBedNumber = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
				
				set PAADMPAPMIDR = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
				
				Set tPatientName = tFicha_"/"_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			
				If $g(RecLocID) = "" 
				{
					Set tSC = $System.Status.Error(5001,"Dispatching Location is null")
					Quit
				}
			
				//Local Receptor
				Set RecLocCode   = $p(^CTLOC(RecLocID),"^",1)
				Set RecLocCodeERP   = $p(^CTLOC(RecLocID),"^",55)
				Set RecHospID 	 = $p(^CTLOC(RecLocID),"^",22)
				Set RecHospCode  = $p(^CT("HOSP",RecHospID),"^",1)
			
				//Local Solicitante Unidad Temporal
				Set SolLocCode = $p(^CTLOC(OrdLocID),"^",1)
				///
				Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
				Set StockUpdateMsg.User = $g(%session.Data("LOGON.USERCODE"))
				Set StockUpdateMsg.MovementCode = "S003"
				Set StockUpdateMsg.DocumentNo = tNroReceta
				Set StockUpdateMsg.Episode = tNroEpisodio
				Set StockUpdateMsg.PatientLocation = tBedNumber
				Set StockUpdateMsg.LogisticLocation = RecLocCodeERP
				Set StockUpdateMsg.LocationCode = RecLocCodeERP
				Set StockUpdateMsg.FacilityCode = "1000"
				Set StockUpdateMsg.PatientName = tPatientName
				//Set StockUpdateMsg.CostCenter = "A0ACDAAS01"
			
				&SQL(Declare Return Cursor For
					select sum(ISNULL(DSP_Qty,0))-sum(ISNULL(DSP_ReturnQty,0)), 
					DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
					DSP_INCLB_DR->INCLB_INCIB_DR, 
					DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
					DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR
					into :tQty, :tINCIBExpDate, :tINCIBNo, :tINCIId, :tINCILCTLOCDR
					from sqluser.OE_Dispensing 
					where DSP_OEORE_ParRef->OEORE_OEORI_ParRef %inlist :lOrderIDs and DSP_Status in ('C')
					and DSP_ReturnQty is null
					and DSP_OEORE_ParRef->OEORE_Order_Status_DR->STAT_SystemAdminStatus = 'NOT'
					group by DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
					DSP_INCLB_DR->INCLB_INCIB_DR, 
					DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
					DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR
					)
					
					
			
			
				&SQL(Open Return)
				&SQL(Fetch Return)
				while(SQLCODE=0)
				{
					//set ^zjb("Retorna",tINCIId,2)="2 "_tINCIId
					
					Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
					Set LocCode = $Piece(^CTLOC(tINCILCTLOCDR),"^",1)
					Set StockItem.Quantity = tQty
					
					set tObjBatch = ##class(User.INCItmBat).%OpenId(tINCIBNo)
					set tBatchNumber = tObjBatch.INCIBNo
					if tBatchNumber '= ""
					{
						Set StockItem.BatchNumber = $p(tBatchNumber,";",1)
					}
					if tINCIBExpDate '= ""
					{
						Set StockItem.ExpiryDate = $zd(tINCIBExpDate,8)
					}
					
					///Codigo Item
					set tCodERP = ..GetItemCodeERP(tINCIId)
				
					Set StockItem.StockItemCode = tCodERP
					
					//tINCICode
					Do StockUpdateMsg.Items.Insert(StockItem)
					&SQL(Fetch Return)
				}
				&SQL(Close Return)
			}
		}
		
		if ($Get(%request.Data("TFORM",1))="Pharmacy.ReturnPart.Edit")
		{
			set OrderIDs = $Get(%request.Data("OrderIDs",1))	
			//set ^zjb("RetornaPart",1)="1 "_OrderIDs
			
			if (OrderIDs'="")
			{
				set tOrderItemId = $piece(OrderIDs,"^",1)
				//set ^zjb("RetornaPart",2)="2 "_tOrderItemId
				Set (tQty, tINCIBExpDate, tINCIBNo, tINCICode, tINCILCTLOCDR) = ""
			
				///
				set ObjOrdItem = ##class(User.OEOrdItem).%OpenId(tOrderItemId)
			
				Set RecLocID = ObjOrdItem.OEORIRecDepDR.%Id()
				Set OrdLocID = ObjOrdItem.OEORIOrdDeptDR.%Id()
				Set tNroReceta = ObjOrdItem.OEORIPrescNo
				Set tNroEpisodio = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				Set tBedNumber = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
				set PAADMPAPMIDR = ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
				
				Set tPatientName = tFicha_"/"_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_ObjOrdItem.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
				
				//set ^zjb("RetornaPart",3)="3 "_RecLocID
				If $g(RecLocID) = "" 
				{
					Set tSC = $System.Status.Error(5001,"Dispatching Location is null")
					Quit
				}
			
				//Local Receptor
				Set RecLocCode   = $p(^CTLOC(RecLocID),"^",1)
				Set RecLocCodeERP   = $p(^CTLOC(RecLocID),"^",55)
				Set RecHospID 	 = $p(^CTLOC(RecLocID),"^",22)
				Set RecHospCode  = $p(^CT("HOSP",RecHospID),"^",1)
			
				//Local Solicitante Unidad Temporal
				Set SolLocCode = $p(^CTLOC(OrdLocID),"^",1)
				///
				Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
				
				Set tReturnType=""
				Set tReturnType = $Get(%request.Data("ReasonForINCReturn",1))
				if tReturnType = "Merma / Faltante"
				{
					Set StockUpdateMsg.MovementCode = "S004"
				}
				else
				{
					Set StockUpdateMsg.MovementCode = "S003"
				}
				
				Set tDescription = $Get(%request.Data("ReasonForRefund",1))
				if tDescription '= ""
				{
					Set StockUpdateMsg.Description = $extract(tDescription,1,50)
				}
				
				
				Set StockUpdateMsg.User = $extract($g(%session.Data("LOGON.USERCODE")),1,100)
				Set StockUpdateMsg.DocumentNo = $extract(tNroReceta,1,50)
				Set StockUpdateMsg.Episode = $extract(tNroEpisodio,1,50)
				Set StockUpdateMsg.PatientLocation = $extract(tBedNumber,1,100)
				//Set StockUpdateMsg.LogisticLocation = $p(RecLocCodeERP,";",1)
				Set StockUpdateMsg.LocationCode = $extract(RecLocCodeERP,1,100)
				Set StockUpdateMsg.FacilityCode = "1000"
				Set StockUpdateMsg.PatientName = $extract(tPatientName,1,100)
				//Set StockUpdateMsg.CostCenter = "A0ACDAAS01"
					
				set ind = 1
				
				//set ^zjb("RetornaPart",4)="4 "_$Get(%request.Data("orditmz"_ind,1))
				
				while $Get(%request.Data("orditmz"_ind,1))'= ""
				{
					set tQuantity=$Get(%request.Data("ReturnQtyz"_ind,1))
					
					if tQuantity = "" Set tQuantity=0
					
					////Add
					set tQty = ""
					set tQty = tQuantity
					set tIdDispensing = $Get(%request.Data("orditmz"_ind,1))
					
					if $get(tIdDispensing)'="" set ^DispensingIntegrationHMS(tIdDispensing,"StockUnPacked","S003",$h) = "Cant: "_tQty_" Fecha: "_$zd($p($h,",",1),4)_" Hora: "_$zt($p($h,",",2),2)
					////Add
					
					if tQuantity > 0
					{
						set tCurrentPresc = ""
						set tCurrentPresc=$Get(%request.Data("hidprescnoz"_ind,1))
						
						if ($get(tNroReceta) '= "") && ($get(tCurrentPresc)'="")
						{
							
							if tNroReceta '[ $get(tCurrentPresc)
							{
								set tNroReceta = tNroReceta_"-"_tCurrentPresc
							}
						}
						
						
						set tOrderItemId = $Get(%request.Data("orditmz"_ind,1))
						
											
						//set ^zjb("RetornaPart",5)="5 "_tOrderItemId
						set tObjOrderItem = ##class(User.OEOrdItem).%OpenId(tOrderItemId)
						set tOEORIItmMastDR = tObjOrderItem.OEORIItmMastDR.%Id()
						set tCodItemMast = tObjOrderItem.OEORIItmMastDR.ARCIMCode
						
						
						
						//Codigo Externo
						set tCodItemERP = ""
						set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
						set tLocalHomologacionERP = "SAP"
						if tLocalHomologacionERP '=""
						{
							set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
							set tCodItemERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
						}
						
						//Si no existe Homologacion se manda el codigo del item
						if tCodItemERP = "" set tCodItemERP = tCodItemMast
						
						//set ^zjb("RetornaPart",6)="6 "_tINCICode
						set tINCILCTLOCDR = tObjOrderItem.OEORIRecDepDR.%Id()
					
						set tINCIBNo = $Get(%request.Data("BatchIDz"_ind,1))
						//set ^zjb("RetornaPart",7)="7 tINCIBNo "_tINCIBNo
					
						set tObjBatch = ##class(User.INCItmBat).%OpenId(tINCIBNo)
						set tInci=tObjBatch.INCIBINCIParRef.%Id()
						//set ^zjb("RetornaPart",8)="7 tInci "_tInci
					
						set tBatchNumber = tObjBatch.INCIBNo
				    	set tINCIBExpDate = tObjBatch.INCIBExpDate
				    
						Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
						
						//Para Fines de Obtener el ID al procesar la respuesta de Integración con SAP
						Set StockItem.SerialNumber = tOrderItemId
						
						Set LocCode = $Piece(^CTLOC(tINCILCTLOCDR),"^",1)
						Set StockItem.Quantity = $Get(%request.Data("ReturnQtyz"_ind,1))
						 
						if tINCIBExpDate '= "" Set StockItem.ExpiryDate = $zd(tINCIBExpDate,8), StockItem.BatchNumber = $piece(tBatchNumber,";",1)
						Set StockItem.StockItemCode = tCodItemERP
						//tINCICode
						Do StockUpdateMsg.Items.Insert(StockItem)
					}
					set ind = ind+1
					
				}
						
			}
				
		}
		
		if StockUpdateMsg.Items.Count()>0
		{
			Set StockUpdateMsg.DocumentNo = tNroReceta
		
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			set tWSSend.Timeout = 300
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("Retorna",3)="6 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			//set ^zjb("Retorna",4)="7 "_tSC
			Set tSC = tWSSend.SendEvent(StockUpdateMsg,	.pResponse)
		
			//set ^zjb("Retorna",5)="8 "_tSC
			if pResponse.ERPResponse.ErrorDescription '= "" set ^zjb("EnviaConsulta",9)="9 "_pResponse.ERPResponse.ErrorDescription
			
			
			
			//Procesar la respuesta
			
			if pResponse.ERPResponse.IsError
			{
				set ^zjb("Error",1)="1 "_StockUpdateMsg.DocumentNo
				//Generar Traza para asociar al item de orden en caso de error y volver a enviar
				for i=1:1:StockUpdateMsg.Items.Count()
				{	
					set tOrderId = ""
					set tOrderId = StockUpdateMsg.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tTextError = ""
						if pResponse.ERPResponse.IsError '= "" set tTextError = pResponse.ERPResponse.ErrorDescription
					
						set tTextToResend = ""
						 //1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
						//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
						set tTextToResend = StockUpdateMsg.MovementCode_"(;)"_StockUpdateMsg.DocumentNo_"(;)"_StockUpdateMsg.LocationCode_"(;)"_StockUpdateMsg.FacilityCode_"(;)"_StockUpdateMsg.Items.GetAt(i).StockItemCode_"(;)"_StockUpdateMsg.Items.GetAt(i).Quantity
						if StockUpdateMsg.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_StockUpdateMsg.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
						if StockUpdateMsg.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_StockUpdateMsg.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
						set tTextToResend = tTextToResend_"(;)"_$p($h,",",1)_"(;)"_$p($h,",",2)_"(;)"_$g(%session.Data("LOGON.USERCODE"))_"(;)"_$extract(tTextError,1,55)
						
						//Actualiza estado de Integración
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tTextToResend,"ERR","ERP")
						
					
					}			
				}	
				
			}
			else
			{
				set ^zjb("NoError",1)="1 "_StockUpdateMsg.DocumentNo
				for i=1:1:StockUpdateMsg.Items.Count()
				{
					set tOrderId = ""
					set tOrderId = StockUpdateMsg.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tDescripcion = StockUpdateMsg.DocumentNo_";"_$g(%session.Data("LOGON.USERCODE"))_";"_$p($h,",",1)_";"_$p($h,",",2)
						
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tDescripcion,"E","ERP")
						
					}			
				}	
				
			}
			
			
		}	
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
		}
		Else
		{
			//set ^zjb("Retorna",6)="6 "_tSC
			Set tSC =  tException.AsStatus()
			//set ^zjb("Retorna",7)="6 "_tSC
		}
	}
	
	Quit 1
	*/
}

ClassMethod StockRequest(pOrderIDs As %String, pMsg As websys.Message) As %String
{
	#dim tObjItemRequest as User.INReqItm
	Set tSC = $System.Status.OK()
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.Solicitudes")
		//Salir si no está activa la integracion
		if 'tIntegrationOn 
		{
			Do pMsg.AddItem("E"," Error ","La Integración no está activa") 
			Quit 
		}
		
		
		
		//set ^zjb("aca",1)="aca 1"
		if $get(%request.Data("HidCompletedYN",1))'="Y" 
		{
			//set ^zjb("aca","1.1")="aca 1.1"
			Quit
		}
		
		//set ^zjb("aca",2)="aca 2"
		if pOrderIDs = "" 
		{
			Do pMsg.AddItem("E"," Error "," No se ha selecionado Ninguna Solicitud ") 
			Quit 
		}
		//set ^zjb("aca",3)="aca 3"

	
		set tObjRequest = ##class(User.INRequest).%OpenId(pOrderIDs)
		
		
		set tItemsCount = tObjRequest.ChildINReqItm.Count()
		
		if tItemsCount < 1 
		{
			Do pMsg.AddItem("E"," Error "," No hay Items asociados a la Solicitud ") 
			Quit 
		}
		
		set tObjSend = ##class(Custom.ERP.WS.StockRequest).%New()
		
		//User Name
		set tUserName = tObjRequest.INRQSSUSRDR.SSUSRInitials_"^"_tObjRequest.INRQSSUSRDR.SSUSRName
		set tObjSend.UserName = tUserName
		
		//Si el detalle esta vacio significa que no ha llegado un envío correcto a ERP
		if tObjRequest.INRQRemarks.GetAt(1) = ""
		{
		
			//Local que Solicita
			set tCodReceivingLoc = tObjRequest.INRQRecLocDR.CTLOCCode
			if tCodReceivingLoc = ""
			{
				Do pMsg.AddItem("E"," Error "," Local Solicitante no puede ser nulo ") 
				Quit 
			} 
			set tDescReceivingLoc = tObjRequest.INRQRecLocDR.CTLOCDesc
		
			//Centro de Costo 
			set tCodCostCenter = tObjRequest.INRQRecLocDR.CTLOCGLCCCDR.GLCCCCode
		
			//Buscar Código ERP Relacionado con Local Solicitante
			set tCodERPReceivingLocal = tObjRequest.INRQRecLocDR.CTLOCPagerNo
			//Si el local no tiene Bodega ERP relacionada es una solicitud de consumo, si tiene bodega ERP Asociada es un Traslado
			if tCodERPReceivingLocal = ""
			{
				set tObjSend.MovementCode = "S005"
				set tObjSend.FromLocationCode = tDescReceivingLoc
				if tCodCostCenter = ""
				{
					Do pMsg.AddItem("E"," Error "," El Centro de Costo asociado al Local Solictante no puede ser Nulo ") 
					Quit 
				} 
			
			}
			else
			{
				set tObjSend.MovementCode = "S006"
				set tObjSend.FromLocationCode = tCodERPReceivingLocal

			}
		
			set tObjSend.FromCostCenter = tCodCostCenter
		
		
			//Facility Code
			set tCodHospital = tObjRequest.INRQRecLocDR.CTLOCHospitalDR.HOSPCode
			if tCodHospital = ""
			{
				set tIdHospital = $g(%session.Data("LOGON.HOSPID"))
				set tObjHospital = ##class(User.CTHospital).%OpenId(tIdHospital)
				set tCodHospital = tObjHospital.HOSPCode
			}
			//Buscar Codigo ERP relacionado, ERP SAP Hosmil No lo necesita
		
			set tObjSend.FacilityCode = tCodHospital
		
		
			
			//Local Bodega que provee o despacha
		
			set tCodRequeringLoc = tObjRequest.INRQReqLocDR.CTLOCCode
			if tCodRequeringLoc = ""
			{
				Do pMsg.AddItem("E"," Error "," Local/Bodega que provee no puede ser nulo ") 
				Quit 
			} 
			set tDescRequeringLoc = tObjRequest.INRQRecLocDR.CTLOCDesc
		
		
			//Buscar Código ERP Relacionado con Local que provee
			set tCodERPRequeringLocal = tObjRequest.INRQReqLocDR.CTLOCPagerNo
		
			if tCodERPRequeringLocal = ""
			{
				Do pMsg.AddItem("E"," Error "," Código Bodega ERP que provee no puede ser nulo ") 
				Quit 
			}
		
			set tObjSend.ToLocationCode = tCodERPRequeringLocal
			//Nro Doc Solicitud Trak
			set tObjSend.DocumentNo = tObjRequest.INRQNo
		
			//Recorrer Items
			for i=1:1:tObjRequest.ChildINReqItm.Count()
			{
				set tObjItemSend = ##class(Custom.ERP.WS.StockRequestItems).%New()
				set tObjItemRequest = tObjRequest.ChildINReqItm.GetAt(i)
			
				set tItemStockId = tObjItemRequest.INRQIINCIDR.%Id()
			
			
			
				///Codigo Item
				set tCodERP = ..GetItemCodeERP(tItemStockId)
			
				set tObjItemSend.StockItemCode = tCodERP
				set tObjItemSend.StockItemDesc = tObjItemRequest.INRQIINCIDR.INCIDesc
			
				set tObjItemSend.Quantity = tObjItemRequest.INRQIReqQty
			
				set tObjItemSend.UOMCode = tObjItemRequest.INRQICTUOMDR.CTUOMCode
			
				set tObjItemSend.LineId = tObjItemRequest.%Id()
			
				do tObjSend.Items.Insert(tObjItemSend)
			
			}
			///End loop Items
		}
		//Si ya fue enviada y aceptada la solicitud en ERP, sólo enviar consulta por la orden
		else
		{
			//Local que Solicita
			set tCodReceivingLoc = tObjRequest.INRQRecLocDR.CTLOCCode
			if tCodReceivingLoc = ""
			{
				Do pMsg.AddItem("E"," Error "," Local Solicitante no puede ser nulo ") 
				Quit 
			} 
			
			set tCodERPReceivingLocal = tObjRequest.INRQRecLocDR.CTLOCPagerNo
			//Si el local no tiene Bodega ERP relacionada es una solicitud de consumo, si tiene bodega ERP Asociada es un Traslado
			if tCodERPReceivingLocal = ""
			{
				//Consulta Consumo
				set tObjSend.MovementCode = "S007"
			}
			else
			{
				//Consulta Traslado
				set tObjSend.MovementCode = "S008"	
			}
			
			//Facility Code
			set tCodHospital = tObjRequest.INRQRecLocDR.CTLOCHospitalDR.HOSPCode
			if tCodHospital = ""
			{
				set tIdHospital = $g(%session.Data("LOGON.HOSPID"))
				set tObjHospital = ##class(User.CTHospital).%OpenId(tIdHospital)
				set tCodHospital = tObjHospital.HOSPCode
			}
			//Buscar Codigo ERP relacionado, ERP SAP Hosmil No lo necesita
		
			set tObjSend.FacilityCode = tCodHospital
			
			set tObjSend.DocumentNo = tObjRequest.INRQNo
			
		}
		// Enviar Mensaje
		Set pResponse = ##class(Custom.ERP.WS.StockRequest).%New()
		Set tWSSend = ##class(Custom.ERP.WS.StockRequestServiceSoap).%New()
		
		//Traer la localización de WS según parametros
		Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.Solicitudes")
		If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
		
		//set ^zjb("EnviaConsulta",5)="5 "_tSC
		Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
		//set ^zjb("EnviaConsulta",6)="6 "_tSC
		Quit:$System.Status.IsError(tSC)
		
		Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
		//set ^zjb("EnviaConsulta",7)="7 "_tSC
		Set tSC = tWSSend.SendConsumption(tObjSend,.pResponse)
		
		//set ^zjb("EnviaConsulta",8)="8 "_tSC_" Movement "_tObjSend.MovementCode
		
		//If $System.Status.IsError(tSC) Quit
		
		if 'pResponse.ERPResponse.IsError
		{	
			set tDescription = ""
			set tDescription = pResponse.ERPResponse.ErrorDescription
			
			//set ^zjb("consultaDesp",1)="1 mov "_pResponse.MovementCode_" glosa "_$piece(pResponse.ERPResponse.ErrorDescription,":",1)
			
			if (pResponse.MovementCode = "S007") && ($piece(pResponse.ERPResponse.ErrorDescription,":",1) = "DESPACHADO")
			{
				//set ^zjb("consultaDesp",2)="2 "_pResponse.Items.Count()
				
				for i=1:1:pResponse.Items.Count()
				{
					//set ^zjb("consultaDesp","2.1")="2.1 "
					set tLineId = ""
					set tDispatchQty = ""
					set tLineId = pResponse.Items.GetAt(i).LineId
					set tDispatchQty = pResponse.Items.GetAt(i).Quantity
					set tDispatchDate = $piece($h,",",1)
					
					//set ^zjb("consultaDesp","2.2",tLineId)="2.2 tlineId "_tLineId
					
					if tLineId '= ""
					{
						//set ^zjb("consultaDesp",3,tLineId)="3"	
						//set ^zjb("consultaDesp",3,tLineId)="3 tlineId "_tlineId_" tDispatchQty  "_tDispatchQty
						
						&sql(insert into Custom_User.INReqItem
								   (ItemId_DR,DispatchQty,DispatchDate)
							values (:tLineId,:tDispatchQty,CURRENT_DATE)
							)
						if SQLCODE '= 0
						{
							&sql(Update Custom_User.INReqItem
								 set DispatchQty = :tDispatchQty
								 where ItemId_DR = :tLineId
								 )
							
							If SQLCODE'= ""	 set tDescription = "Error al Consultar"  
							
						}
						
						
					}
					
				}
				
				set tRequestId=""
				set tRequestId = tObjRequest.%Id()
				set tSumaProducto = 0
				&SQL(select ISNULL(sum(ISNULL(a.INRQI_ReqQty,0))- sum(ISNULL(b.DispatchQty,0)),0)
					 into :tSumaProducto
					 from SQLUser.IN_ReqItm a, Custom_User.INReqItem b
					 where a.INRQI_INRQ_ParRef = :tRequestId
 					   and a.%id = b.ItemId_DR
 					 )
 				if SQLCODE'=0
 				{
	 				set tSumaProducto = ""
	 				set tDescription = "Error al Consultar" 
	 				
 				}
 				
 				if tSumaProducto = 0
 				{
	 				set tDescription = "DESPACHADO TOTAL" 
 				}
 				
 				if tSumaProducto > 0
 				{
	 				set tDescription = "DESPACHADO PARCIALMENTE" 
 				}
			}
			
			
			
			set tDescription = $replace(tDescription,"de devolucion","")
			//set ^zjb("ConsultaConsumo",1)= "1 "_tDescription
			if tDescription = $c(0) set tDescription = "Error al Consultar"
			
			
			set tDateTime = $zdt($h,4)
			
			if tObjRequest.INRQRemarks.GetAt(1)'= ""
			{   
				set tPosition1 = tObjRequest.INRQRemarks.GetAt(1)
				set tPosition2 = tObjRequest.INRQRemarks.GetAt(2)
				do tObjRequest.INRQRemarks.Clear()
				do tObjRequest.INRQRemarks.Insert(tPosition1)
				do tObjRequest.INRQRemarks.Insert(tPosition2)
				do tObjRequest.INRQRemarks.Insert(tDateTime)
				do tObjRequest.INRQRemarks.Insert(tDescription)
				
			}
			else
			{
				do tObjRequest.INRQRemarks.Insert(tDateTime)
				do tObjRequest.INRQRemarks.Insert("ENVIADO A ERP: "_tDescription)
				
			}
			
			
			
			do tObjRequest.%Save()
			
		}
		//Es Error
		else
		{
			set tObjRequest.INRQUserCompleted = "N"
			do tObjRequest.%Save()
			set tError = pResponse.ERPResponse.ErrorDescription
			Do pMsg.AddItem("E","Validación"," "_tError)
		}
		
		//set pResponse.LocationCode = $Piece(^CTLOC(+pLoc),"^",1)
		//set ^zjb("Update Stock",2)="2 "_pResponse.LocationCode
		
		//set tFinalResponse = ##class(Custom.Nexus.WS.ResponseEvent).%New()
		
		//set tSC = ##class(Custom.Nexus.WSEventHandler.StockHandler).StockReGenerator(pResponse,.tFinalResponse)
				
		
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
		}
		Else
		{
		
			Set tSC =  tException.AsStatus()
		}
		
		set tObjRequest.INRQUserCompleted = "N"
		do tObjRequest.%Save()
		Set bRet=0
	}
	
	set ^zjb("aca",4)="aca 4 "_tSC
	
	Quit "1"
}

ClassMethod OnAfterSaveSO(pMsg As websys.Message) As %Status
{
	//set ^zjb("OnAfterPatient",3)="aca 3"
	Set tSC = $System.Status.OK()
	Set bRet=1
	
	set tOverride = ""
	set tOverride = $get(%request.Data("TOVERRIDE",1))
	
	//set ^zjb("After",1)="1 tOverride "_tOverride
	if tOverride = ""
	{
		Try
		{
			//set ^zjb("alert",1)="1"
			Do pMsg.AddItem("I"," Informacion "," Mensaje para mostrar de Informacion")
			//set ^zjb("alert",2)="2"
		}
		
		Catch (tException)
		{
			Set tSC = tException.AsStatus()
			Set bRet=0
		}
	}
	Quit bRet
}

ClassMethod GetItemExtCodeByLoc(pItmMastId, pLocationId) As %String
{
	Set tExternalCode=""
	
	If ((pLocationId="") || (pItmMastId="")) Quit ""
	Set pItmMastIdx = $p(pItmMastId,"||",1) If (pItmMastIdx="") Quit ""
	Set pItmMastCS = $p(pItmMastId,"||",2) If (pItmMastCS="") Quit ""
	Set tDateFrom = $o(^ARCIM(pItmMastIdx,pItmMastCS,"EXT",0,"LOC",pLocationId,""))
	Set tFound=0
	While (tDateFrom'="") {
		If (tDateFrom<=+$h) {
			Set tExtCodeCS = $o(^ARCIM(pItmMastIdx,pItmMastCS,"EXT",0,"LOC",pLocationId,tDateFrom,""))
			While (tExtCodeCS'="") {				
				Set tExtCodeData = $g(^ARCIM(pItmMastIdx,pItmMastCS,"EXT",tExtCodeCS))				
				Set tExtDateTo = $p(tExtCodeData,"^",2) ;EXT_DateTo 
				if ((tExtDateTo="") || (tExtDateTo>=+$h)) {									
					Set tExternalCode = $p(tExtCodeData,"^",4) 					
					Set tFound=1 Quit
				}
				Set tExtCodeCS = $o(^ARCIM(pItmMastIdx,pItmMastCS,"EXT",0,"LOC",pLocationId,tDateFrom,tExtCodeCS))
			}
		}
		If (tFound=1) Quit
		Set tDateFrom = $o(^ARCIM(pItmMastIdx,pItmMastCS,"EXT",0,"LOC",pLocationId,tDateFrom))
	}
	
	if tExternalCode = ""
	{
		set tObjOrder = ##class(User.ARCItmMast).%OpenId(pItmMastId)
		set tExternalCode = tObjOrder.ARCIMCode
		
	}
	Quit tExternalCode
}

ClassMethod GetItemCodeERP(pItmStockId) As %String
{
	Try
	{
		set tSC = $$$OK
		set tCodItemERP=""
		set tDescripcion=""
	
		if pItmStockId = "" 
		{
			set tCodItemERP = ""
			set tDescripcion = "No Existe el Código de Stock"
			Quit 
			//_";"_tDescripcion
		}
		set tObjStock = ##class(User.INCItm).%OpenId(pItmStockId)
	
		set tItemOrdenId = ""
	
		if $IsObject(tObjStock.INCIARCIMDR) set tItemOrdenId = tObjStock.INCIOriginalARCIMDR.%Id()
	
		if tItemOrdenId '= ""
		{
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodItemERP = ..GetItemExtCodeByLoc(tItemOrdenId,tERPLocationId)
			
				//set ^zjb("CodItem",1)= "1 "_tCodItemERP
					
			}
					
		}
		else
		{
			set tCodItemERP = tObjStock.INCIText1
		
		}
	
		if tCodItemERP = ""
		{
			set tCodItemERP = tObjStock.INCICode
		}
	}
	Catch (tException)
	{
		Set tSC = tException.AsStatus()
		set tCodItemERP = ""
		
	}
	
	Quit tCodItemERP
}

ClassMethod ListFilterSolicitud(pRS) As %Integer
{

	set text = ""
	set text1 = ""
	set text2 = ""
	set text3 = ""
	set text4 = ""
	set tRequestId = ""
	set tObjRequest = ""
	
	set tRequestNo = $g(pRS.Data("INRQNo"))
	
	if tRequestNo '= ""
	{
		set tRequestId= ##class(web.INRequest).GetIdFromRequestNo(tRequestNo)
		if tRequestId '= ""
		{
			set tObjRequest = ##class(User.INRequest).%OpenId(tRequestId)
			if '($IsObject(tObjRequest)) quit 1
				
			set text1 = tObjRequest.INRQRemarks.GetAt(1)
			set text2 = tObjRequest.INRQRemarks.GetAt(2)
			set text3 = tObjRequest.INRQRemarks.GetAt(3)
			set text4 = tObjRequest.INRQRemarks.GetAt(4)
			
			set text = text1_" "_text2_"<BR>"_text3_" "_text4			
		}
	}
	
	set pRS.Data("ERPStatus")=text
	
	quit 1
}

ClassMethod StockMasterRequest(pItemID As %String, pMsg As websys.Message) As %String
{
	
	#dim tObjItem as User.INCItm
	Set tSC = $System.Status.OK()
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.Maestros")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	

		//set ^zjb("ItemMast",1)= "1 "_pItemID
		
		set tUpdateType = $g(%request.Data("TEVENT",1))
		
		if tUpdateType = "d3833iupdate1"
		{
			if pItemID = "" 
			{
				Do pMsg.AddItem("E"," Error "," Id del Item no puede nulo ") 
				Quit 
			}
		
			set tObjStockItem = ##class(User.INCItm).%OpenId(pItemID)
			if '$isObject(tObjStockItem) 
			{
				Do pMsg.AddItem("E"," Error "," El Item de Stock no pudo ser identificado ") 
				Quit
			}
		
			//Facility Code se debe implementar en el caso de integración con multiple Hospitales
		
			set tFacilityCode = "100"
		
			set tUserCode = $g(%session.Data("LOGON.USERCODE"))
			set tUserName = $g(%session.Data("LOGON.USERNAME"))
		
			//Tipo de Movimiento para crear un Material
			set tMovementCode = "S050"
		
			set tUOMCode = tObjStockItem.INCICTUOMDR.CTUOMCode
			if tUOMCode = ""
			{
				Do pMsg.AddItem("E"," Error "," La unidad de Medida del Item de Stock no pudo ser identificado ") 
				Quit
			}
		
		
			//Item Types to ERP
		
			set tServiceFlag = tObjStockItem.INCIFlag2
			if tServiceFlag = "" set tServiceFlag = "N"
		
			if $IsObject(tObjStockItem.INCIOriginalARCIMDR)
			{
				set tTypeI = "Y"
				set tTypeP = "Y"
				set tTypeS = "Y"
			}
			else
			{
				if tServiceFlag = "Y"
				{
					set tTypeI = "N"
					set tTypeP = "Y"
					set tTypeS = "N"
				}
				else
				{
					set tTypeI = "Y"
					set tTypeP = "Y"
					set tTypeS = "N"
				}
			}
			//set ^zjb("ItemMast",2)= "2 tUOMCode "_tUOMCode
		
			set tStockGroup = tObjStockItem.INCIINCTGDR.INCTGCode
			if tStockGroup = ""
			{
				Do pMsg.AddItem("E"," Error "," El Grupo de Stock no puede ser Nulo ") 
				Quit	
			}
		
			///Codigo Item
			set tCodERP = ..GetItemCodeERP(pItemID)
		
		
			set tActive = ""
			set tActive = tObjStockItem.INCIFlag1
			if tActive = "" set tActive = "N"
			
			set tItemDescription = $extract(tObjStockItem.INCIDesc,1,100)
		
			//Batch Requered?
			set tBatchRequered = tObjStockItem.INCIBatchReq
			if tBatchRequered = "R"
			{
				set tBatchRequered = "Y"	
			}
			else
			{
				set tBatchRequered = "N"	
			}
		
			//ExpiryDate Requered?
			set tExpiryDate = tObjStockItem.INCIExpReq
			if tExpiryDate = "R"
			{
				set tExpiryDate = "Y"	
			}
			else
			{
				set tExpiryDate = "N"	
			}
		
			//Definir con ERP de que forma le sirve este dato
				
			//set ^zjb("ItemMast",4)= "4 tBatchRequered "_tBatchRequered_" tExpiryDate "_tExpiryDate
		
			set tObjToSend = ##class(Custom.ERP.WS.StockMaster).%New()
		
			set tObjToSend.Active = tActive
			set tObjToSend.BatchNumber = tBatchRequered
			set tObjToSend.ExpiryDate = tExpiryDate
			set tObjToSend.FacilityCode = tFacilityCode
			set tObjToSend.ItemInventory = tTypeI
			set tObjToSend.ItemPurchase = tTypeP
			set tObjToSend.ItemSale = tTypeS
			set tObjToSend.MovementCode = tMovementCode
			set tObjToSend.StockGroup = tStockGroup
			set tObjToSend.StockItemCode = tCodERP
			set tObjToSend.UOMCode = tUOMCode
			set tObjToSend.UserCode = tUserCode
			set tObjToSend.UserName = tUserName
			set tObjToSend.StockItemDesc = tItemDescription
		
			//set ^zjb("ItemMast",5)="5 tactive "_tActive_" tSC "_tSC
		 
		 	for i=1:1:tObjStockItem.ChildINCItmLoc.Count()
			{
				set tObjLocalItem = tObjStockItem.ChildINCItmLoc.GetAt(i)
				set tObjLocal = tObjStockItem.ChildINCItmLoc.GetAt(i).INCILCTLOCDR
			
				if tActive '= "Y"
				{
					set tObjLocalItem.INCILDateTo = $p($h,",",1)
				}
				
				if ($get(^flagInventoryActiveERP(pItemID)) = "N") && (tActive = "Y")
				{
					set tObjLocalItem.INCILDateTo = ""
				}
				do tObjLocalItem.%Save()
				
				//set ^zjb("StockIns",1)="cod SAP "_tObjLocal.CTLOCPagerNo_" Cod Local "_tObjLocal.CTLOCCode
			
				if tObjLocal.CTLOCPagerNo '= ""
				{
					set tDateTo = tObjLocalItem.INCILDateTo
					if tDateTo = "" set tDateTo=99999999
				
					if tDateTo > $piece($h,",",1)
					{
						set tActiveLocal = "Y"
					}
					else
					{
						set tActiveLocal = "N"
					}
					 
					set tObjLocToSend = ##class(Custom.ERP.WS.StockMasterLocation).%New()
				
				
					set tObjLocToSend.Active = tActiveLocal
					set tObjLocToSend.StockLocalCode = tObjLocal.CTLOCPagerNo
					set tObjLocToSend.StockLocalDesc = tObjLocal.CTLOCDesc
				
					do tObjToSend.Local.Insert(tObjLocToSend)
				
				
				}
			
			
			}
			//set ^zjb("StockIns",2)="2 count "_tObjToSend.Local.Count()_" tServiceFlag "_tServiceFlag
			
			if (tObjToSend.Local.Count() = 0) && (tServiceFlag'="Y")
		 	{
			 	Do pMsg.AddItem("E"," Error "," El item debe tener al menos una Bodega ERP asociada ") 
				Quit
		 	}
			
			//set ^zjb("ItemMast",6)="6 "_tSC		
			//Envio de Mensaje
			Set pResponse = ##class(Custom.ERP.WS.Response).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockMasterItemsSoap).%New()
			
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.Maestros")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			//set ^zjb("EnviaMaster",7)="7 "_tSC
			Set tSC = tWSSend.SendMasterItem(tObjToSend,.pResponse)
		
			//set ^zjb("EnviaMaster",8)="8 "_tSC
			if pResponse.IsError
			{
				set tError = pResponse.ErrorDescription 
				Do pMsg.AddItem("E"," Error ","Error Integración  "_tError)
			}
			else
			{
				Do pMsg.AddItem("PUW"," Info ","Datos Integrados Correctamente")
			
			} 
		
		}
	}
	Catch (tException)
	{
		Set tSC = tException.AsStatus()
		Do pMsg.AddItem("E"," Error ","Error de Comunicación con la Integración de Maestros  "_$System.Status.GetErrorText(tSC))
		//set ^zjb("aca",4)="aca 4 tSC "_tSC
		Set bRet=0
	}
	
	
	Quit "1"
}

ClassMethod InsumosToERP(OrderIds) As %Status
{
	Set tSC = $$$OK
	//set ^zjb("InsumosToERP",1)="1 "_OrderIds
	
	if OrderIds = "" Quit tSC
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.Solicitudes")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	
		
			
		set ind = 1
		set tId = $piece($piece(OrderIds,"^",ind),"*",2)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		
		while tId '=""
		{	
			//set ^zjb("ItemIns",1)="1 "_tId
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			//set ^zjb("ItemIns",2)="2 "_tObjOrder
			set tAdmId = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.%Id()
			//set ^zjb("ItemIns",3)="3 "_'$IsObject(tObjOrder)
			if '$IsObject(tObjOrder) Quit
			//Se Construye una sola vez el Encabezado
			
			//Chack si la subcategoria corresponde a Insumos a ERP
			set tSubcategoryCode = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICCommissioning
			//set ^zjb("ItemIns",4)="4 tSubcategoryCode "_tSubcategoryCode
			
			if (tSubcategoryCode '= "") && (tSubcategoryCode = "Y")
			{
				//set ^zjb("ItemIns",4)="4 "_tSubcategoryCode
				if InsCount = 1 
				{
					//set ^zjb("ItemIns",5)="5 "
					//Facility Code
					set tIdHospital = $g(%session.Data("LOGON.HOSPID"))
					set tObjHospital = ##class(User.CTHospital).%OpenId(tIdHospital)
					set tCodHospital = tObjHospital.HOSPCode
					//set ^zjb("ItemIns",5)="5 "_tCodHospital
					//User Name
					set tUserName = $g(%session.Data("LOGON.USERCODE"))_"^"_$g(%session.Data("LOGON.USERNAME"))
				
					set tObjSend = ##class(Custom.ERP.WS.StockRequest).%New()
					set tObjSend.FacilityCode = tCodHospital
					set tObjSend.UserName = tUserName
					set tObjSend.MovementCode = "S005"
				
					Set tObjSend.FromLocationCode = tObjOrder.OEORIOrdDeptDR.CTLOCDesc
					Set tObjSend.FromCostCenter = tObjOrder.OEORIOrdDeptDR.CTLOCGLCCCDR.GLCCCCode
					Set tObjSend.PatientLocation = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
					
					set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}	
					
					Set tObjSend.PatientName = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
					Set tObjSend.Episode = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
					//set ^zjb("ItemIns",6)="6 tObjSend.Episode "_tObjSend.Episode
					Set tObjSend.ToLocationCode = tObjOrder.OEORIRecDepDR.CTLOCPagerNo
				
					if tObjSend.ToLocationCode = "" set tObjSend.ToLocationCode = tObjOrder.OEORIRecDepDR.CTLOCCode
					
					set InsCount =  InsCount + 1
					
					//set ^zjb("ItemIns",7)="7 InsCount "_InsCount
					if $get(^InsumosCounterERP)=""
					{
						set ^InsumosCounterERP = 1
					}
					else
					{
						set ^InsumosCounterERP = ^InsumosCounterERP+1
					}
			
					set tNroIns = "INS"_$tr($j(^InsumosCounterERP,8)," ",0)
					
				}
				
				set tObjSend.DocumentNo = tNroIns
				set tObjOrder.OEORIText3 = tNroIns
				do tObjOrder.%Save()
				
				set tObjSendItem = ##class(Custom.ERP.WS.StockRequestItems).%New()
				
				set tItemMasterCode = tObjOrder.OEORIItmMastDR.ARCIMCode 
				//set ^zjb("ItemIns",6)="6 tItemMasterCode "_tItemMasterCode
				//Codigo Externo
				set tCodItemERP = ""
				set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
				set tLocalHomologacionERP = "SAP"
				if tLocalHomologacionERP '=""
				{
					set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
					set tCodItemERP = ..GetItemExtCodeByLoc(tItemMasterCode,tERPLocationId)
				}
				//set ^zjb("ItemIns",7)="7 tCodItemERP "_tCodItemERP
				if tCodItemERP = "" set tCodItemERP = tItemMasterCode
				
				//set ^zjb("ItemIns",8)="8 tCodItemERP "_tCodItemERP
				
				set tObjSendItem.StockItemCode = tCodItemERP
				set tObjSendItem.Quantity =  tObjOrder.OEORIPhQtyOrd
				set tObjSendItem.LineId = tObjOrder.%Id()
				
				Set tObjSendItem.SerialNumber = tOrderId
				
				do tObjSend.Items.Insert(tObjSendItem)
			}
			
			set ind = ind+1
			set tId = $piece($piece(OrderIds,"^",ind),"*",2)
		}
		//set ^zjb("ItemIns",11)="11 "_tObjSend.Items.Count()
		if tObjSend.Items.Count() > 0 
		{
			// Enviar Mensaje
			Set pResponse = ##class(Custom.ERP.WS.StockRequest).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockRequestServiceSoap).%New()
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.Solicitudes")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			//set ^zjb("ItemIns",12)="12 "_tSC
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("ItemIns",13)="13 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			//set ^zjb("ItemIns",14)="14 "_tSC
			Set tSC = tWSSend.SendConsumption(tObjSend,.pResponse)
		
			//set ^zjb("ItemIns",15)="15 "_tSC
			if pResponse.ERPResponse.ErrorDescription '= "" //set ^zjb("ItemIns",9)="9 "_pResponse.ERPResponse.ErrorDescription
			//If $System.Status.IsError(tSC) Quit
		
			
			if 'pResponse.ERPResponse.IsError
			{
				set tDescripcion = $g(%session.Data("LOGON.USERCODE"))_";"_$p($h,",",1)_";"_$p($h,",",2)
				&sql(Update %NOLOCK %NOTRIGGER SQLUser.OE_OrdItem set OEORI_Text4 = 'E', OEORI_Text3 = OEORI_Text3||';'||:tDescripcion
				     where OEORI_OEORD_ParRef->OEORD_Adm_DR=:tAdmId and OEORI_Text3 = :tNroIns )
					
			}
			
		}
		
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		//set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
		
	Quit tSC
}

ClassMethod SentToERPBodegasPerifesricas(OrderIds) As %Status
{
	Set tSC = $$$OK
	//set ^zjb("NewPeris",1)="1 "_OrderIds
	
	if OrderIds = "" Quit tSC
	Try
	{
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		set tgroupId = $i(^HMSDispensacionGroup)
		while tId '=""
		{	
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue
			}
			
			&sql(Update %nolock %notrigger SQLUser.OE_OrdItem
				 set OEORI_Billed = 'TB'
				 where %id = :tId
				   and OEORI_Billed <> 'P'
				)
				
			set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
			set tObjToInsert.OrderGroupId = tgroupId
			set tObjToInsert.OrderRef = tObjOrder
					
			//Cantidad
			set (tCantidad,tSubcategoriaType) = ""
			set tSubcategoriaType = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrderType
			if ($g(tSubcategoriaType) = "R") || ($g(tSubcategoriaType) = "I")
			{
				set tCantidad = 0
				set qty=$piece($get(^OEORD(ord,"I",itm,1)),"^",12)
	 			set uom=$piece($get(^OEORD(ord,"I",itm,2)),"^",3)
	 			set arcim=$piece($get(^OEORD(ord,"I",itm,1)),"^",2)
	 			set drgform=$piece($get(^ARCIM(+arcim,1,1)),"^",12)
				set tCantidad = $$calcqty^aOET7(drgform,uom,qty)
					
			}
			else
			{
				set tCantidad =  tObjOrder.OEORIPhQtyOrd
			}
			set tObjToInsert.Cantidad = tCantidad
				
			//Tipo Movimiento 
			set tObjToInsert.TipoMovimiento = "S002"
				
			//Locales 
			set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
					
			if $IsObject(tObjOrder.OEORIRecDepDR)
			{	
				Set tObjLocal = tObjOrder.OEORIRecDepDR
			}
					
			if $IsObject(tObjLocal)
			{
				Set tLocalERP = tObjLocal.CTLOCPagerNo
				if $IsObject(tObjLocal.CTLOCGLCCCDR)
				{
					set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
				}
					
				set tObjToInsert.LocalTrak = tObjLocal
				set tObjToInsert.LocalCodeERP = tLocalERP
				set tObjToInsert.CentroCosto = tCentroCosto
				set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
			}
				
			//Nro Documento
			set (NroDoumento)=""
			set tNroDocumento = tObjOrder.OEORIPrescNo
			if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
			set tObjToInsert.NroDocumento = tNroDocumento
				
			//Usuario
			set tObjToInsert.Usuario = $g(%session.Data("LOGON.USERCODE"))
				
				
			//Episodio
			set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
			//Paciente
			set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
			if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
			{
				set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
				
				Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			}

				
			///Datos Item
			set tCodERP = ""
			set tOEORIItmMastDR = tObjOrder.OEORIItmMastDR.%Id()
			set tCodItemMast = tObjOrder.OEORIItmMastDR.ARCIMCode
						
			//Codigo Externo
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
			}
						
			//Si no existe Homologacion se manda el codigo del item
			if tCodERP = "" set tCodERP = tCodItemMast
			set tObjToInsert.CodigoERP = tCodERP
			
										
			set tObjToInsert.Lote = ""
			set tObjToInsert.FecVencimiento = ""
						
			set tObjToInsert.CantIntentos = 0
			set tObjToInsert.EstadoEnvio = "Ingresado"
			set tObjToInsert.ProcIngreso = "SentToERPBodegasPerifesricas-OEOrder.Custom"
				
			set tSC = tObjToInsert.%Save()
			
			
			set tUserIdTrak = $g(%session.Data("LOGON.USERID"))
			if tUserIdTrak = "" set tUserIdTrak = ##class(Custom.HMIL.Bill.Rules.GenericV2016).GetCtaUserId()
			//do ..PackAndExecuteOrderBP(tId)
			//do ChangeStatus^COEOrdItem5(tId,"E",tUserIdTrak,"","")
			
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
		
		set tResp = ..EnvioDispToERP("Grupo", "", tgroupId,$g(%session.Data("LOGON.USERCODE")))

	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		
	}
	//set ^zjb("NewPeris","Error")=tSC
	
	Quit tSC
	
	
	
	/* Codigo Anterior
	Set tSC = $$$OK
	set ^zjb("InsumosToERPBP",1)="1 "_OrderIds
	
	if OrderIds = "" Quit tSC
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//Salir si no está activa la integracion
		//if 'tIntegrationOn Quit	
		
			
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		
		while tId '=""
		{	
			set ^zjb("ItemIns",1)="1 "_tId
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			set tNroOrdenERP = ""
			set tNroOrdenERP = tObjOrder.OEORIPrescNo
			if tNroOrdenERP="" set tNroOrdenERP = tObjOrder.OEORIBBExtCode
			//set ^zjb("ItemIns",2)="2 "_tObjOrder
			set tAdmId = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.%Id()
			//set ^zjb("ItemIns",3)="3 "_'$IsObject(tObjOrder)
			if '$IsObject(tObjOrder) Quit
			//Se Construye una sola vez el Encabezado
			
			//Check si la subcategoria corresponde a Insumos a ERP
			set tSubcategoryCode = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICCommissioning
			set tSubcategoriaType = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrderType
			set ^zjb("ItemIns",4)="4 tSubcategoryCode "_tSubcategoryCode
			
			
			//Add
			set tCantidad = ""
			if (tSubcategoriaType = "R") || (tSubcategoriaType = "I")
			{
					//Cantidad
				set tCantidad = 0
				set qty=$piece($get(^OEORD(ord,"I",itm,1)),"^",12)
	 			set uom=$piece($get(^OEORD(ord,"I",itm,2)),"^",3)
	 			set arcim=$piece($get(^OEORD(ord,"I",itm,1)),"^",2)
	 			set drgform=$piece($get(^ARCIM(+arcim,1,1)),"^",12)
		
				set tCantidad = $$calcqty^aOET7(drgform,uom,qty)
					
			}
			else
			{
				set tCantidad =  tObjOrder.OEORIPhQtyOrd
			}
			
			
			
			if $get(tId)'="" set ^DispensingIntegrationHMS(tId,"SendBP","S002",$h) = "Cant: "_tCantidad_" Fecha: "_$zd($p($h,",",1),4)_" Hora: "_$zt($p($h,",",2),2)
			
			
			//Add
			
			
			
			//if (tSubcategoryCode '= "") && (tSubcategoryCode = "Y")
			//{
				set ^zjb("ItemIns",4)="4 "_tSubcategoryCode
				if InsCount = 1 
				{
					set ^zjb("ItemIns",5)="5 "
					//Facility Code
					//set tIdHospital = $g(%session.Data("LOGON.HOSPID"))
					//set tObjHospital = ##class(User.CTHospital).%OpenId(tIdHospital)
					//set tCodHospital = tObjHospital.HOSPCode
					//set ^zjb("ItemIns",5)="5 "_tCodHospital
					//User Name
					set tUserName = $g(%session.Data("LOGON.USERNAME"))
				
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					if $g(%session.Data("LOGON.USERCODE")) '= ""
					{
						set tObjSend.User = $g(%session.Data("LOGON.USERCODE"))
					}
					else
					{
						set tObjSend.User = "IntDisp"
					}
					
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroOrdenERP
					//set tObjSend.User = tUserName
					set tObjSend.MovementCode = "S002"
					
					//Set tObjSend.FromLocationCode = tObjOrder.OEORIOrdDeptDR.CTLOCDesc
					//Set tObjSend.FromCostCenter = tObjOrder.OEORIOrdDeptDR.CTLOCGLCCCDR.GLCCCCode
					//Set tObjSend.PatientLocation = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
					
					set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}		
					
					Set tObjSend.PatientName = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
					Set tObjSend.Episode = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
					set ^zjb("ItemIns",6)="6 tObjSend.Episode "_tObjSend.Episode
					Set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCPagerNo
					Set tObjSend.CostCenter = tObjOrder.OEORIRecDepDR.CTLOCGLCCCDR.GLCCCCode
				
					if tObjSend.LocationCode = "" set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCCode
					
					
				}
				
				set InsCount =  InsCount + 1
				set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
				set tItemMasterId = tObjOrder.OEORIItmMastDR.%Id() 
				set tItemMasterCode = tObjOrder.OEORIItmMastDR.ARCIMCode 
				set ^zjb("ItemIns",7)="7 tItemMasterCode "_tItemMasterCode
				//Codigo Externo
				set tCodItemERP = ""
				set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
				set tLocalHomologacionERP = "SAP"
				if tLocalHomologacionERP '=""
				{
					set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
					set tCodItemERP = ..GetItemExtCodeByLoc(tItemMasterId,tERPLocationId)
				}
				set ^zjb("ItemIns",7)="7 tCodItemERP "_tCodItemERP
				if tCodItemERP = "" set tCodItemERP = tItemMasterCode
				
				//set ^zjb("ItemIns",8)="8 tCodItemERP "_tCodItemERP
				
				set tObjSendItem.StockItemCode = tCodItemERP
				
				if (tSubcategoriaType = "R") || (tSubcategoriaType = "I")
				{
					//Cantidad
					set tCantidad = 0
					set qty=$piece($get(^OEORD(ord,"I",itm,1)),"^",12)
	 				set uom=$piece($get(^OEORD(ord,"I",itm,2)),"^",3)
	 				set arcim=$piece($get(^OEORD(ord,"I",itm,1)),"^",2)
	 				set drgform=$piece($get(^ARCIM(+arcim,1,1)),"^",12)
		
					set tCantidad = $$calcqty^aOET7(drgform,uom,qty)
					
					set tObjSendItem.Quantity =  tCantidad
				}
				else
				{
					set tObjSendItem.Quantity =  tObjOrder.OEORIPhQtyOrd
				}
				
				set tObjSendItem.SerialNumber = tObjOrder.%Id()
				
				
				
				do tObjSend.Items.Insert(tObjSendItem)
			//}
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
		//set ^zjb("ItemIns",11)="11 "_tObjSend.Items.Count()
		if tObjSend.Items.Count() > 0 
		{
			
			//Inicio Antes de en enviar el mensaje incluir dato de error por defecto en caso que no llegue a obtener respuesta desde Sap
			for i=1:1:tObjSend.Items.Count()
			{
			
				set tOrderId = ""
				set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
				if tOrderId '= ""
				{
					set tTextError = "No se ha Establecido comunicacion con SAP"
					set tTextToResend = ""
				 	//1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
					//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
					set tTextToResend = tObjSend.MovementCode_"(;)"_tObjSend.DocumentNo_"(;)"_tObjSend.LocationCode_"(;)"_tObjSend.FacilityCode_"(;)"_tObjSend.Items.GetAt(i).StockItemCode_"(;)"_tObjSend.Items.GetAt(i).Quantity
					if tObjSend.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
					if tObjSend.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
					set tTextToResend = tTextToResend_"(;)"_$p($h,",",1)_"(;)"_$p($h,",",2)_"(;)"_$g(%session.Data("LOGON.USERCODE"))_"(;)"_$extract(tTextError,1,55)
				
					set tUserIdTrak = $g(%session.Data("LOGON.USERID"))
					if tUserIdTrak = "" set tUserIdTrak = ##class(Custom.HMIL.Bill.Rules.GenericV2016).GetCtaUserId()
					//Actualiza estado de Integración
					//set tRespUpdate = ..UpdateTextResponse(tOrderId,tTextToResend,"ERR","ERP",tTextError)
					do ..PackAndExecuteOrderBP(tOrderId)
					do ChangeStatus^COEOrdItem5(tOrderId,"E",tUserIdTrak,"","")
				}			
			}
					
			//Fin Antes de en enviar el mensaje incluir dato de error por defecto en caso que no llegue a obtener respuesta desde Sap
			
			
			
			
			// Enviar Mensaje
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			set tWSSend.Timeout = 300
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			set ^zjb("ItemIns",12)="12 "_tSC
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("ItemIns",13)="13 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			set ^zjb("ItemIns",14)="14 "_tSC
			Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
			
			set ^zjb("ItemIns",15)="15 "_tSC
			if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcion = pResponse.ERPResponse.ErrorDescription
			//If $System.Status.IsError(tSC) Quit
			
			if pResponse.ERPResponse.IsError
			{
				set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
				//Generar Traza para asociar al item de orden en caso de error y volver a enviar
				for i=1:1:tObjSend.Items.Count()
				{	
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tTextError = ""
						if pResponse.ERPResponse.IsError '= "" set tTextError = pResponse.ERPResponse.ErrorDescription
					
						set tTextToResend = ""
						 //1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
						//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
						set tTextToResend = tObjSend.MovementCode_"(;)"_tObjSend.DocumentNo_"(;)"_tObjSend.LocationCode_"(;)"_tObjSend.FacilityCode_"(;)"_tObjSend.Items.GetAt(i).StockItemCode_"(;)"_tObjSend.Items.GetAt(i).Quantity
						if tObjSend.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
						if tObjSend.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
						set tTextToResend = tTextToResend_"(;)"_$p($h,",",1)_"(;)"_$p($h,",",2)_"(;)"_$g(%session.Data("LOGON.USERCODE"))_"(;)"_$extract(tTextError,1,55)
						
						set tUserIdTrak = $g(%session.Data("LOGON.USERID"))
						if tUserIdTrak = "" set tUserIdTrak = ##class(Custom.HMIL.Bill.Rules.GenericV2016).GetCtaUserId()
						//Actualiza estado de Integración
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tTextToResend,"ERR","ERP")
						//do ..PackAndExecuteOrderBP(tOrderId)
						//do ChangeStatus^COEOrdItem5(tOrderId,"E",tUserIdTrak,"","")
					
					}			
				}
					
			}
			else
			{
				set ^zjb("NoError",1)="1 "_tObjSend.DocumentNo
				for i=1:1:tObjSend.Items.Count()
				{
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tUserIdTrak = $g(%session.Data("LOGON.USERID"))
						
						if tUserIdTrak = "" set tUserIdTrak = ##class(Custom.HMIL.Bill.Rules.GenericV2016).GetCtaUserId()
						
						
						
						set tDescripcion = tObjSend.DocumentNo_";"_$g(%session.Data("LOGON.USERCODE"))_";"_$p($h,",",1)_";"_$p($h,",",2)
						
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tDescripcion,"E","ERP")
						
						
						//do ..PackAndExecuteOrderBP(tOrderId)
						//do ChangeStatus^COEOrdItem5(tOrderId,"E",tUserIdTrak,"","")
					}			
				}	
				
			}
			
		}
		
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
	set ^zjb("ItemIns",18)="18 tSC "_tSC
	Quit tSC
	
	*/
}

ClassMethod SentToERPBodegasInsumos(OrderIds) As %Status
{
	Set tSC = $$$OK
	set ^zjb("InsumosToERP2",1)="1 "_OrderIds
	
	if OrderIds = "" Quit tSC
	Try
	{
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	
		
			
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		
		while tId '=""
		{	
			//set ^zjb("ItemIns",1)="1 "_tId
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			set tNroOrdenERP = ""
			set tNroOrdenERP = tObjOrder.OEORIPrescNo
			if tNroOrdenERP="" set tNroOrdenERP = tObjOrder.OEORIBBExtCode
			//set ^zjb("ItemIns",2)="2 "_tObjOrder
			set tAdmId = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.%Id()
			//set ^zjb("ItemIns",3)="3 "_'$IsObject(tObjOrder)
			if '$IsObject(tObjOrder) Quit
			//Se Construye una sola vez el Encabezado
			
			//Check si la subcategoria corresponde a Insumos a ERP
			set tSubcategoryCode = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICCommissioning
			set tSubcategoriaType = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrderType
			//set ^zjb("ItemIns",4)="4 tSubcategoryCode "_tSubcategoryCode
			
			if (tSubcategoryCode '= "") && (tSubcategoryCode = "Y")
			{
				//set ^zjb("ItemIns",4)="4 "_tSubcategoryCode
				if InsCount = 1 
				{
					//set ^zjb("ItemIns",5)="5 "
					//Facility Code
					//set tIdHospital = $g(%session.Data("LOGON.HOSPID"))
					//set tObjHospital = ##class(User.CTHospital).%OpenId(tIdHospital)
					//set tCodHospital = tObjHospital.HOSPCode
					//set ^zjb("ItemIns",5)="5 "_tCodHospital
					//User Name
					set tUserName = $g(%session.Data("LOGON.USERNAME"))
				
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroOrdenERP
					set tObjSend.User =  $g(%session.Data("LOGON.USERCODE"))
					//set tObjSend.u = tUserName
					set tObjSend.MovementCode = "S005"
					
					//Set tObjSend.FromLocationCode = tObjOrder.OEORIOrdDeptDR.CTLOCDesc
					//Set tObjSend.FromCostCenter = tObjOrder.OEORIOrdDeptDR.CTLOCGLCCCDR.GLCCCCode
					//Set tObjSend.PatientLocation = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
					
					set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}		
					
					Set tObjSend.PatientName = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
					Set tObjSend.Episode = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
					//set ^zjb("ItemIns",6)="6 tObjSend.Episode "_tObjSend.Episode
					Set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCPagerNo
					Set tObjSend.CostCenter = tObjOrder.OEORIRecDepDR.CTLOCGLCCCDR.GLCCCCode
				
					if tObjSend.LocationCode = "" set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCCode
					
					
				}
				
				set InsCount =  InsCount + 1
				set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
				set tItemMasterId = tObjOrder.OEORIItmMastDR.%Id() 
				set tItemMasterCode = tObjOrder.OEORIItmMastDR.ARCIMCode 
				set ^zjb("ItemIns2",6)="6 tItemMasterCode "_tItemMasterCode
				//Codigo Externo
				set tCodItemERP = ""
				set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
				set tLocalHomologacionERP = "SAP"
				if tLocalHomologacionERP '=""
				{
					set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
					set tCodItemERP = ..GetItemExtCodeByLoc(tItemMasterId,tERPLocationId)
				}
				set ^zjb("ItemIns2",7)="7 tCodItemERP "_tCodItemERP
				if tCodItemERP = "" set tCodItemERP = tItemMasterCode
				
				//set ^zjb("ItemIns",8)="8 tCodItemERP "_tCodItemERP
				
				set tObjSendItem.StockItemCode = tCodItemERP
				
				if (tSubcategoriaType = "R") || (tSubcategoriaType = "I")
				{
					//Cantidad
					set tCantidad = 0
					set qty=$piece($get(^OEORD(ord,"I",itm,1)),"^",12)
	 				set uom=$piece($get(^OEORD(ord,"I",itm,2)),"^",3)
	 				set arcim=$piece($get(^OEORD(ord,"I",itm,1)),"^",2)
	 				set drgform=$piece($get(^ARCIM(+arcim,1,1)),"^",12)
		
					set tCantidad = $$calcqty^aOET7(drgform,uom,qty)
					
					set tObjSendItem.Quantity =  tCantidad
				}
				else
				{
					set tObjSendItem.Quantity =  tObjOrder.OEORIPhQtyOrd
				}
				
				set tObjSendItem.SerialNumber = tObjOrder.%Id()
				set tObjSendItem.MedicalProgram = tObjOrder.%Id()
				
				
				
				do tObjSend.Items.Insert(tObjSendItem)
			}
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
		//set ^zjb("ItemIns",11)="11 "_tObjSend.Items.Count()
		if tObjSend.Items.Count() > 0 
		{
			// Enviar Mensaje
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			//set ^zjb("ItemIns",12)="12 "_tSC
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("ItemIns",13)="13 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			//set ^zjb("ItemIns",14)="14 "_tSC
			Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
			//set ^zjb("ItemIns",15)="15 "_tSC
			if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcion = pResponse.ERPResponse.ErrorDescription
			//If $System.Status.IsError(tSC) Quit
			
			if pResponse.ERPResponse.IsError
			{
				set ^zjb("Error2",1)="1 "_tObjSend.DocumentNo
				//Generar Traza para asociar al item de orden en caso de error y volver a enviar
				for i=1:1:tObjSend.Items.Count()
				{	
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tTextError = ""
						if pResponse.ERPResponse.IsError '= "" set tTextError = pResponse.ERPResponse.ErrorDescription
					
						set tTextToResend = ""
						 //1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
						//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
						set tTextToResend = tObjSend.MovementCode_"(;)"_tObjSend.DocumentNo_"(;)"_tObjSend.LocationCode_"(;)"_tObjSend.FacilityCode_"(;)"_tObjSend.Items.GetAt(i).StockItemCode_"(;)"_tObjSend.Items.GetAt(i).Quantity
						if tObjSend.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
						if tObjSend.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
						set tTextToResend = tTextToResend_"(;)"_$p($h,",",1)_"(;)"_$p($h,",",2)_"(;)"_$g(%session.Data("LOGON.USERCODE"))_"(;)"_$extract(tTextError,1,55)
						
						//Actualiza estado de Integración
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tTextToResend,"ERR","ERP")
						
					
					}			
				}
					
			}
			else
			{
				set ^zjb("NoError2",1)="1 "_tObjSend.DocumentNo
				for i=1:1:tObjSend.Items.Count()
				{
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tDescripcion = tObjSend.DocumentNo_";"_$g(%session.Data("LOGON.USERCODE"))_";"_$p($h,",",1)_";"_$p($h,",",2)
						
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tDescripcion,"E","ERP","")
						
					}			
				}	
				
			}
			
		}
		
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		set ^zjb("ItemIns2",17)="17 tSC "_tSC
		
	}
	set ^zjb("ItemIns2",18)="18 tSC "_tSC
	Quit tSC
}

ClassMethod LogisticToERP(OrderIds, pAdmId, pNroOrder) As %Status
{
	Set tSC = $$$OK
	set ^zjb("InsumosToERP",1)="1 OrderIds "_OrderIds_" pNroOrder "_pNroOrder_" pAdmId "_pAdmId
	
	if OrderIds = "" Quit
	Try
	{	
		//set tSC = ..AddNroOrderIntegrated(OrderIds)
	
	
		set ^zjb("EnvioBP",1)="1 pAdmId "_pAdmId_" pNroOrder "_pNroOrder
	
		/////Enviar a ERP según los casos
		//Caso 1 Comportamiento de dispensacion Bodegas Periferica
		set tBodegaERP = ""
		&sql(Declare CBodegasToERP Cursor for
		     select distinct OEORI_RecDep_DR
		     into :tBodegaERP
			 from SQLUser.OE_OrdItem
			 where OEORI_OEORD_ParRef->OEORD_Adm_DR = :pAdmId
  			   and OEORI_BBExtCode = :pNroOrder
  			   and OEORI_RecDep_DR->CTLOC_ExternalInfoSystem = 'SONA'
  			   and OEORI_RecDep_DR is not null
  			   and OEORI_RecDep_DR->CTLOC_PagerNo is not null
  			   and OEORI_Priority_DR->OECPR_Code not in ('OM')
  			 )
  		 
  		//if SQLCODE'=0 quit
  	
  		//Enviar a ERP según las distintas Bodegas en cuestion
  	
  		&SQL(Open CBodegasToERP)
		&SQL(Fetch CBodegasToERP)
		
		
		while(SQLCODE=0)
		{
			set ^zjb("EnvioBP",2)="2 tBodegaERP "_tBodegaERP_" pAdmId "_pAdmId_" pNroOrder "_pNroOrder
			&sql(Declare CSentItemsToERP Cursor for
		     	select %id, OEORI_ItmMast_DR
		     	into :tOrdIdToERP, :tItemMastId
			 	from SQLUser.OE_OrdItem
			 	where OEORI_OEORD_ParRef->OEORD_Adm_DR = :pAdmId
  			  	  and OEORI_BBExtCode = :pNroOrder
  			   	  and OEORI_RecDep_DR->CTLOC_ExternalInfoSystem = 'SONA'
  			      and OEORI_RecDep_DR is not null
  			      and OEORI_RecDep_DR->CTLOC_PagerNo is not null
  			      and OEORI_RecDep_DR = :tBodegaERP
  			      and OEORI_Priority_DR->OECPR_Code not in ('OM')
  			 	)
			//if SQLCODE'=0 quit
			&SQL(Open CSentItemsToERP)
			&SQL(Fetch CSentItemsToERP)
			set tListIdOrd = ""
			while(SQLCODE=0)
			{
				//Verifica que tenga un Item de Stock relacionado
				if $order(^INCI(0,"ARCIM_DR",+tItemMastId,""))'= ""
				{
					set pUserId = $Get(%session.Data("LOGON.USERID"))
					//do ChangeStatus^COEOrdItem5(tOrdIdToERP,"E",pUserId,"","")
					
					if tListIdOrd = ""
					{
						set tListIdOrd = tOrdIdToERP
					}
					else
					{
						set tListIdOrd = tListIdOrd_","_tOrdIdToERP
					}
				}
				
				&SQL(Fetch CSentItemsToERP)
			}
			
			&SQL(Close CSentItemsToERP)
			set ^zjb("EnvioBP",3,tBodegaERP)="1 "_tListIdOrd
			set tSC = ..SentToERPBodegasPerifesricas(tListIdOrd)
			
			&SQL(Fetch CBodegasToERP)
		}
		&SQL(Close CBodegasToERP)
	
	///////Fin caso 1 Bodega Periferica Ambulatoria
	
	
	//////Comienzo Envío de Insumos que deben crear un solicitud de consumo a Despachar desde ERP
	
		set tBodegaERP2 = ""
		&sql(Declare CBodegasToERP2 Cursor for
		     select distinct OEORI_RecDep_DR
		     into :tBodegaERP2
			 from SQLUser.OE_OrdItem
			 where OEORI_OEORD_ParRef->OEORD_Adm_DR = :pAdmId
  			   and OEORI_BBExtCode = :pNroOrder
  			   and OEORI_RecDep_DR->CTLOC_ExternalInfoSystem is null
  			   and OEORI_ItmMast_DR->ARCIM_PHCDF_DR is null
  			   and OEORI_RecDep_DR is not null
  			   and OEORI_RecDep_DR->CTLOC_PagerNo is not null
  			 )
  		 
  		//if SQLCODE'=0 quit
  	
  		//Enviar a ERP según las distintas Bodegas en cuestion
  	
  		&SQL(Open CBodegasToERP2)
		&SQL(Fetch CBodegasToERP2)
		
		
		while(SQLCODE=0)
		{
			set ^zjb("EnvioBP2",2)="2 tBodegaERP "_tBodegaERP_" pAdmId "_pAdmId_" pNroOrder "_pNroOrder
			&sql(Declare CSentItemsToERP2 Cursor for
		     	select %id, OEORI_ItmMast_DR
		     	into :tOrdIdToERP2, :tItemMastId2
			 	from SQLUser.OE_OrdItem
			 	where OEORI_OEORD_ParRef->OEORD_Adm_DR = :pAdmId
  			  	  and OEORI_BBExtCode = :pNroOrder
  			   	  and OEORI_RecDep_DR->CTLOC_ExternalInfoSystem is null
  			   	  and OEORI_ItmMast_DR->ARCIM_PHCDF_DR is null
  			  	  and OEORI_RecDep_DR is not null
  			      and OEORI_RecDep_DR->CTLOC_PagerNo is not null
  			      and OEORI_RecDep_DR = :tBodegaERP2
  			 	)
			//if SQLCODE'=0 quit
			&SQL(Open CSentItemsToERP2)
			&SQL(Fetch CSentItemsToERP2)
			set tListIdOrd2 = ""
			while(SQLCODE=0)
			{
				//Verifica que tenga un Item de Stock relacionado
				if $order(^INCI(0,"ARCIM_DR",+tItemMastId2,""))'= ""
				{
					if tListIdOrd2 = ""
					{
						set tListIdOrd2 = tOrdIdToERP2
					}
					else
					{
						set tListIdOrd2 = tListIdOrd2_","_tOrdIdToERP2
					}
				}
				
				
				&SQL(Fetch CSentItemsToERP2)
			}
			
			&SQL(Close CSentItemsToERP2)
			set ^zjb("EnvioBP2",3,tBodegaERP2)="1 "_tListIdOrd2
			set tSC = ..SentToERPBodegasInsumos(tListIdOrd2)
			
			&SQL(Fetch CBodegasToERP2)
		}
		&SQL(Close CBodegasToERP2)
	
	
	//////Fin Envío de Insumos que deben crear un solicitud de consumo a Despachar desde ERP
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
		
	set ^zjb("ItemIns",18)="18 tSC "_tSC	
	Quit tSC
}

ClassMethod InsumosToERP2(OrderIds, pEpidodeId) As %Status
{
	Set tSC = $$$OK
	
	if OrderIds = "" Quit tSC
	Try
	{
		set tId = $piece($piece(OrderIds,"^",ind),"*",2)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set ind = 1, tNroIns = "", InsCount = 1
		
		while tId '=""
		{	
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			if '$IsObject(tObjOrder) Quit
			
			//Check si la subcategoria corresponde a Insumos a ERP
			set tSubcategoryCode = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICCommissioning
			
			if (tSubcategoryCode '= "") && (tSubcategoryCode = "Y")
			{
				if InsCount = 1 
				{
					//set ^zjb("ItemIns",5)="5 "
					set InsCount =  InsCount + 1
					
					if $get(^InsumosCounterERP)=""
					{
						set ^InsumosCounterERP = 1
					}
					else
					{
						set ^InsumosCounterERP = ^InsumosCounterERP+1
					}
			
					set tNroIns = "INS"_$tr($j(^InsumosCounterERP,8)," ",0)
					
				}
				
				set tObjSend.DocumentNo = tNroIns
				set tObjOrder.OEORIText3 = tNroIns
				do tObjOrder.%Save()
				
				
			}
			
			set ind = ind+1
			set tId = $piece($piece(OrderIds,"^",ind),"*",2)
		}
		
		if tNroIns '= ""
	
		if tObjSend.Items.Count() > 0 
		{
			// Enviar Mensaje
			Set pResponse = ##class(Custom.ERP.WS.StockRequest).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockRequestServiceSoap).%New()
			//set ^zjb("ItemIns",12)="12 "_tSC
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("ItemIns",13)="13 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			//set ^zjb("ItemIns",14)="14 "_tSC
			Set tSC = tWSSend.SendConsumption(tObjSend,.pResponse)
		
			//set ^zjb("ItemIns",15)="15 "_tSC
			if pResponse.ERPResponse.ErrorDescription '= "" //set ^zjb("ItemIns",9)="9 "_pResponse.ERPResponse.ErrorDescription
			//If $System.Status.IsError(tSC) Quit
		
			
			if 'pResponse.ERPResponse.IsError
			{
				set tDescripcion = $g(%session.Data("LOGON.USERCODE"))_";"_$h
				&sql(Update SQLUser.OE_OrdItem set OEORI_Text4 = 'E', OEORI_Text3 = OEORI_Text3||';'||:tDescripcion
				     where OEORI_OEORD_ParRef->OEORD_Adm_DR=:tAdmId and OEORI_Text3 = :tNroIns )
					
			}
			
		}
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		//set ^zjb("ItemIns",17)="17 tSC "_tSC
	}
		
	Quit tSC
}

ClassMethod StockServiceRequest(pItemID As %String, pMsg As websys.Message) As %String
{
	
	#dim tObjItem as User.ARCItmMast
	Set tSC = $System.Status.OK()
	Try
	{
		//set ^zjb("ItemServ",1)= "1 "_pItemID
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.Maestros")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	

		if pItemID = "" 
		{
			Do pMsg.AddItem("E"," Error "," Id del Item no puede nulo ") 
			Quit 
		}
		
		set tObjItemMast = ##class(User.ARCItmMast).%OpenId(pItemID)
		if '$isObject(tObjItemMast) 
		{
			Do pMsg.AddItem("E"," Error Integracion "," El Item de Orden no pudo ser identificado ") 
			Quit
		}
		
		//Facility Code se debe implementar en el caso de integración con multiple Hospitales
		
		set tFacilityCode = "100"
		
		set tUserCode = $g(%session.Data("LOGON.USERCODE"))
		set tUserName = $g(%session.Data("LOGON.USERNAME"))
		
		///Tipo de Movimiento para crear un Servicio
		set tMovementCode = "S051"
		
		set tUOMCode = tObjItemMast.ARCIMUOMDR.CTUOMCode
		//Verificar si será una restricción
		
		//if tUOMCode = ""
		//{
		//	Do pMsg.AddItem("E"," Error "," El Item de Stock no pudo ser identificado ") 
		//	Quit
		//}
		
		
		set tServiceMaterial = tObjItemMast.ARCIMServMaterial
		
		// Si no está definido el tipo de Orden o si es Material no Enviar
		if (tServiceMaterial = "") || (tServiceMaterial="M" ) Quit
		
		//Item Types to ERP
		if tServiceMaterial = "S"
		{
			set tTypeI = "N"
			set tTypeP = "N"
			set tTypeS = "Y"
		}
		
		//set ^zjb("ItemServ",2)= "2 tServiceMaterial "_tServiceMaterial
		
		//Verificar una posible Homologación con códigos SAP que serán correlativos
		set tBillingSubGroupCode = tObjItemMast.ARCIMBillSubDR.ARCSGCode
		set tBillingGroupCode = tObjItemMast.ARCIMBillSubDR.ARCSGARCBGParRef.ARCBGCode
		set tBillingGroupSAP = tObjItemMast.ARCIMBillSubDR.ARCSGARCBGParRef.ARCBGAbbrev
		
		
		if tBillingSubGroupCode = ""
		{
			Do pMsg.AddItem("E"," Error Integracion "," El Grupo de Orden no puede ser Nulo ") 
			Quit	
		}
				
		
		///Codigo Item
		set tItemMasterCode = tObjItemMast.ARCIMCode 
		//set ^zjb("ItemIns",6)="6 tItemMasterCode "_tItemMasterCode
		//Codigo Externo
		set tCodItemERP = ""
		set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
		set tLocalHomologacionERP = "SAP"
		if tLocalHomologacionERP '=""
		{
			set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
			set tCodItemERP = ..GetItemExtCodeByLoc(tItemMasterCode,tERPLocationId)
		}
		
		//Verificar esta condicion
		if tCodItemERP = "" set tCodItemERP = tItemMasterCode
		
		//if tCodItemERP = tItemMasterCode
		//{
		//	Do pMsg.AddItem("W"," Alerta "," Código ERP es igual al Código del Item de Stock, ¿Desea Continuar? ") 
		//}
		

		set tActive = ""
		set tDateTo = tObjItemMast.ARCIMEffDateTo
		if tDateTo = "" set tDateTo=99999999
				
		if tDateTo > $piece($h,",",1)
		{
			set tActive = "Y"
		}
		else
		{
			set tActive = "N"
		}
		
		set ^zjb("ItemServ",31)= "31 tActive "_tActive_" tDateTo "_tDateTo
			
		//if tActive'= "Y"
		//{
		//	set tActive = "N"
		//	Do pMsg.AddItem("W"," Alerta "," Está ingresando un árticulo en estado Inactivo ") 
		//}
			
		
		
		set tItemDescription = $extract(tObjItemMast.ARCIMDesc,1,150)
		
		
		set tObjToSend = ##class(Custom.ERP.WS.StockMaster).%New()
		
		set tObjToSend.Active = tActive
		set tObjToSend.ItemInventory = tTypeI
		set tObjToSend.ItemPurchase = tTypeP
		set tObjToSend.ItemSale = tTypeS
		//Arreglar cuando los codigos SAP estén disponibles
		//set tObjToSend.StockGroup = tBillingGroupCode_tBillingSubGroupCode
		//set tObjToSend.StockGroup = "171"
		set tObjToSend.StockGroup = tBillingGroupSAP
		set tObjToSend.StockItemCode = tCodItemERP
		set tObjToSend.UOMCode = tUOMCode
		set tObjToSend.UserCode = tUserCode
		set tObjToSend.UserName = tUserName
		set tObjToSend.StockItemDesc = tItemDescription
		set tObjToSend.MovementCode = tMovementCode
		
			
		
		
		//Validar que la Integración esté Activa
		//Envio de Mensaje
		Set pResponse = ##class(Custom.ERP.WS.Response).%New()
		Set tWSSend = ##class(Custom.ERP.WS.StockMasterItemsSoap).%New()
		
		Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.Maestros")
		//set ^zjb("ItemServ",6)="6 "_tIntegrationOn
		If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
		
		
		Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
		Quit:$System.Status.IsError(tSC)
		
		Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
		//set ^zjb("EnviaMaster",7)="7 "_tObjToSend
		Set tSC = tWSSend.SendMasterItem(tObjToSend,.pResponse)
		
		//set ^zjb("EnviaMaster",8)="8 "_tSC
		
		if pResponse.IsError
		{
			set tError = pResponse.ErrorDescription 
			Do pMsg.AddItem("E"," Error ","Error Integración  "_tError)
		}
		else
		{
			Do pMsg.AddItem("PUW"," Info ","Datos Integrados Correctamente")
			
		} 
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
		}
		Else
		{
		
			Set tSC =  tException.AsStatus()
		}
		//set ^zjb("aca",4)="aca 4 tSC "_tSC
		Set bRet=0
	}
	
	Quit "1"
}

ClassMethod ListEstadoInsumos(pRS) As %Integer
{
	
	set Printed = ""
	set Printed = $g(%request.Data("FindNotPrinted",1))
	
	set Payed = ""
	set Payed = $g(%request.Data("FindPayed",1))
	
	set Resume = ""
	set Resume = $g(%request.Data("CheckResume",1))
	
	//set ^zjb("InsEstado",0)=" 0 Printed "_Printed_" Payed "_Payed_" Resume "_Resume
	
	set tId = "", tObjId = "" , tText3 = "",  tText4 = "", tFinalText = ""
	
	
	set tId = $g(pRS.Data("ID"))
	
	
	if tId '= "" set tObjId = ##class(User.OEOrdItem).%OpenId(tId)
	if tId '= "" set tObjId2 = ##class(User.OEOrdItem2).%OpenId(tId)
	
	
	if $isObject(tObjId)
	{
		
		set tPhyQty = ""
		set tPhyQty = tObjId.OEORIPhQtyOrd
		
		set tFinalTextERP = ""
		set tFinalTextDIS = ""
		set tERPText4=""
		set tERPText3=""
		
		set tDISText4=""
		set tDISText3=""
		
		set tNroDoc = ""
		set tNroDoc = tObjId.OEORIPrescNo
		set tCodItemMast = tObjId.OEORIItmMastDR.ARCIMCode
		
		if tCodItemMast '= ""
		{
			///Filtrar por Numero receta
			set tPrescFilter = $g(%request.Data("PresCode",1))
			
			if ($get(tPrescFilter)'="") && ($get(tPrescFilter)'= $get(tCodItemMast))
			{
				quit 0
			}
			
		}
		
		if tNroDoc '= ""
		{
			///Filtrar por Numero receta
			set tPrescFilter = $g(%request.Data("PresNoCustom",1))
			
			if ($get(tPrescFilter)'="") && ($get(tPrescFilter)'= $get(tNroDoc))
			{
				quit 0
			}
			
		}
		
		if tNroDoc = ""
		{
			set tNroDoc = tObjId.OEORILabEpisodeNo
		}
		
		if tNroDoc = ""
		{
			set tNroDoc = tObjId.OEORIBBExtCode
		}
		
		if tNroDoc '= ""
		{
			///Filtrar por Numero receta
			set tPrescFilter = $g(%request.Data("PresNoCustom",1))
			
			if ($get(tPrescFilter)'="") && ($get(tPrescFilter)'= $get(tNroDoc))
			{
				quit 0
			}
			
		}
		
		set (tExisteEnvio,tERPText4New) =""
		set tExisteEnvio = $order(^Custom.User.DispensacionesERPI("IndexOrderRef",tId,""))
		if tExisteEnvio '= ""
		{
			set countError = 0
			&sql(select count(*)
			    into :countError
				from Custom_User.DispensacionesERP
				where OrderRef = :tId
  			  	and estadoEnvio in ('Error','Ingresado')
  			  	)
  			if SQLCODE '= 0 set countError = 0
  			
  			if countError > 0
  			{
  				set tERPText4New = "ERR"
  			}
  			
  		
		}

		set tText4 = tObjId.OEORIText4
		set tText3 = tObjId.OEORIText3
		
		set tERPText4=$piece(tText4,"-DIS-",1)
		set tDISText4=$piece(tText4,"-DIS-",2)
		
		set tERPText3=$piece(tText3,"-DIS-",1)
		set tDISText3=$piece(tText3,"-DIS-",2)
		
		//set ^zjb("filtroNew",1,tId)=" tExisteEnvio "_tExisteEnvio_" tERPText4New "_tERPText4New
		
		
		//Check para busqueda de errores de ERP
		set tErrorERP = ""
		set tErrorERP = $g(%request.Data("FindERPError",1))
		//set ^zjb("filtroNew",2,tId)=" tErrorERP "_tErrorERP_" tERPText4New "_tERPText4New
			
		if ($get(tErrorERP) '= "") && (tErrorERP="on")
		{
			if (tERPText4 = "ERR") || (tERPText4New="ERR")
			{

			}
			else
			{
				quit 0
			}
		}
		
		
		
		
		if tExisteEnvio = ""
		{
			if tERPText4 = ""
			{
				set tFinalTextERP = "ERP: No Enviado"
			}
			elseif tERPText4 = "E" 
			{
			
				if tERPText3 '= "" 
				{
					set tUser = $p(tERPText3,";",2), tDate = $p(tERPText3,";",3), tTime = $p(tERPText3,";",4)
					if tDate '= "" set tDate = $zd(tDate,4)
					if tTime '= "" set tTime = $zt(tTime,1)
				
					if tNroDoc '= ""
					{
						set tFinalTextERP = "Enviado a ERP: "_tUser_" Fecha: "_tDate_" "_tTime
					}
					else
					{
						set tFinalTextERP = "Enviado a ERP: "_tUser_" Fecha: "_tDate_" "_tTime
					}
				}
			
			
			}
			elseif tERPText4 = "ERR" 
			{
				if tERPText3 '= "" 
				{
					 //1 Tipo Mov;2 NroReceta/Docto;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 Fecha ($h); 10 Hora($h);11 Cod Usuario, 12 Error
				
					set tUser = $p(tERPText3,"(;)",11), tDate = $p(tERPText3,"(;)",9), tTime = $p(tERPText3,"(;)",10)
					if tDate '= "" set tDate = $zd(tDate,4)
					if tTime '= "" set tTime = $zt(tTime,1)
				
					set tError = $p(tERPText3,"(;)",12)
					set tTipoMov = $p(tERPText3,"(;)",1)
					set tTipoDesc =""
					if tTipoMov = "S002" set tTipoDesc = "Dispensación"
					if tTipoMov = "S003" set tTipoDesc = "Devolución"
					if tTipoMov = "S004" set tTipoDesc = "Merma" 
					if tTipoDesc = ""
					{				
						set tFinalTextERP = "Error ERP Integracion. Usuario: "_tUser_" Fecha: "_tDate_" "_tTime_". Det: "_tError
					}
					else
					{
						set tFinalTextERP = "Error ERP Tipo: "_tTipoDesc_". Usuario "_tUser_" Fecha: "_tDate_" "_tTime_". Det: "_tError
					}
				}
			
			
			}
			elseif tERPText4 = "D" 
			{
	
				if tERPText3 '= "" 
				{
					set tUser = $p(tERPText3,";",2), tDate = $p(tERPText3,";",3), tTime = $p(tERPText3,";",4)
					if tDate '= "" set tDate = $zd(tDate,4)
					if tTime '= "" set tTime = $zt(tTime,1)
				
					set tFinalTextERP = "Despachado por Usuario: "_tUser_" Cant. Solicitado "_$p(tERPText3,";",5)_" Despachado "_$p(tERPText3,";",6)_" Fecha: "_tDate_" "_tTime
				}
			
			
			}
		}
		else //Nueva Forma de envio
		{
			if tERPText4New = "ERR"
			{
				set tFinalTextERP = "Ver Envios Pendientes o con errores ERP "
			}
			else
			{
				set tFinalTextERP = "Ver Detalle Envio ERP"
			}
			
			
		}
		
		
	/////Dispensadores
		
		if tDISText4 = ""
		{
			set tFinalTextDIS = "Kardex/Omnicell: No Enviado"
		}
		elseif tDISText4 = "E" 
		{
			
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",2), tTime = $p(tDISText3,";",3)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				if tNroDoc '= ""
				{
					set tFinalTextDIS = "Enviado a Kardex/Omnicell: "_tUser_" Fecha: "_tDate_" "_tTime
				}
				else
				{
					set tFinalTextDIS = "Enviado a  Kardex/Omnicell "_tUser_" Fecha: "_tDate_" "_tTime
				}
			}
			
			
		}
		elseif tDISText4 = "ER" 
		{
			set tDISText3 = tObjId.OEORIText3
			if tDISText3 '= "" 
			{
				set tError = $p(tDISText3,"[",1)
								
				set tFinalTextDIS = "Error DIS Integracion: "_tError
			}
			
			
		}
		elseif tDISText4 = "D"
		{
	
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",4), tTime = $p(tDISText3,";",5)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tDetalle = " Total: "_$p(tDISText3,";",2)_" Dispensado "_$p(tDISText3,";",3)
				set tMayorDisp = ""
				set tMayorDisp = $p(tDISText3,";",6)
				
				set tFinalTextDIS = "Dispensado por Usuario: "_tUser_tDetalle_" Fecha: "_tDate_" "_tTime
				
				if tMayorDisp '= "" set tFinalTextDIS = "Dispensado por Usuario: "_tUser_tDetalle_" Fecha: "_tDate_" "_tTime_" ERR: Se ha dispensado "_tMayorDisp_" unidades más que lo solicitado"
			}
			
			
		}
		elseif tDISText4 = "DP"
		{	//set ^zjb("Disp",tId,2)= "2 "_tDISText4_" tDISText3 "_tDISText3
	
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",4), tTime = $p(tDISText3,";",5)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tDetalle = " Total: "_$p(tDISText3,";",2)_" Dispensado "_$p(tDISText3,";",3)
				
				set tFinalTextDIS = "Dispensado por Usuario: "_tUser_tDetalle_" Fecha: "_tDate_" "_tTime
			}
			
			
		}
		elseif tDISText4 = "NS"
		{	//set ^zjb("Disp",tId,2)= "2 "_tDISText4_" tDISText3 "_tDISText3
	
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",4), tTime = $p(tDISText3,";",5)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tDetalle = " No hay sufuciente Stock Disponible en Bodega. Requerido: "_$p(tDISText3,";",2)_" Disponible: "_$p(tDISText3,";",3)
				
				set tFinalTextDIS = "Error DIS Integracion: "_tDetalle_" Fecha: "_tDate_" "_tTime
			}
			
			
		}
	}
	//Datos de Impresión Custom
	set tImpresion = ""
	set tImpresion = tObjId2.ITM2ExternalPaperPrescNo
	if $get(tImpresion) = ""
	{
		if (tDISText4 = "D") || (tDISText4 = "DP") || (tDISText4 = "NS")
		{
			set tImpresion = "Impreso"
		}
	}
	
	
	if (Printed = "on") && (tImpresion'="") 
	{
		Quit 0
	}
	
	
	
	
	if tImpresion '= ""
	{
		set tUsr = $piece(tImpresion,";",1)
		set tDate = $piece(tImpresion,";",2)
		set tTime = $piece(tDate,",",2)
		set tDate = $piece(tDate,",",1)
		
		if tDate '= "" set tDate = $zd(tDate,4)
		if tTime '= "" set tTime = $zt(tTime,1)
		
		set tImpresion = "Usr: "_tUsr_" Fecha "_tDate_" "_tTime
	}
	else
	{
		set tImpresion = "No Impreso"
	}
	
	
	//Datos de Pago de ERP Custom
	set (tPago,tPagoInicial) = ""
	set tPago = tObjId2.ITM2OverrideOrderLineName
	set tPagoInicial = tObjId2.ITM2OverrideOrderLineName
	//if $get(tId)="2222196||1" set ^zjb("tPago",1)=tPago
	
	if tPago '= ""
	{
		set tPago = $piece(tPago,"||",2)

	}	
	
	if (Payed = "on") && (tPago ="") 
	{
		Quit 0
	}
	
	
	//if $get(tId)="2222196||1" set ^zjb("tPago",2)=tPago
		
	if (tPago = "") && (tPagoInicial'="")
	{
		//if $get(tId)="2222196||1" set ^zjb("tPago",3)=tPago
		set tPago = $piece(tPagoInicial,"||",1)
		//if $get(tId)="2222196||1" set ^zjb("tPago",4)=tPago
	}
	
	if tPago '= ""
	{
		//set tPago = $piece(tPago,"||",2)
		set tTipoMovERP = $piece(tPago,";",1)
		if tTipoMovERP = "E" 
		{
			set tERPAction = "Enviado a ERP: "
			set tUserEnvio = $piece(tPago,";",2)
			set tDate = $piece(tPago,";",3)
			set tTime = $piece(tDate,",",2)
			set tDate = $piece(tDate,",",1)
		
			if tDate '= "" set tDate = $zd(tDate,4)
			if tTime '= "" set tTime = $zt(tTime,1)
			
			set tPago = tERPAction_"Usr "_tUserEnvio_" "_tDate_" "_tTime
		
		}
		else
		{
			if tTipoMovERP = "P" set tERPAction = "Pagado: "
			if tTipoMovERP = "AN" set tERPAction = "Anulado: "
			set tDate = $piece(tPago,";",2)
			set tTime = $piece(tDate,",",2)
			set tDate = $piece(tDate,",",1)
		
			if tDate '= "" set tDate = $zd(tDate,4)
			if tTime '= "" set tTime = $zt(tTime,1)
			
			set tPago = tERPAction_tDate_" "_tTime
		}
		
		
	}
	
	
	
	set pRS.Data("ExtPaperPrescNo") = tImpresion
	set pRS.Data("PAPMIName7") = tFinalTextERP
	set pRS.Data("PAPMIName5") = tFinalTextDIS
	set pRS.Data("PAPMIName8") = tPhyQty
	set pRS.Data("PAPMIName6") = tNroDoc
	
	if tPago = "" set tPago = "No Enviado a ERP"
	set pRS.Data("PAPMIName4") = tPago
	
	quit 1
}

ClassMethod ListEstadoLaboratorio(pRS) As %Integer
{
	
	;
	;Desc		: Lista de Trabajo Laboratorio: Oculta registros sin Número de orden.
	;Component	: OEOrdItem.RadiologyWorkBrench
	;Author		: cvega
	;Date		: 2019-01-02
	;	
	
	
	if ($get(pRS.Data("OEORILabEpisodeNo"))=""){
		quit 0
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	set Printed = ""
	set Printed = $g(%request.Data("FindNotPrinted",1))
	
	set Payed = ""
	set Payed = $g(%request.Data("FindPayed",1))
	
	set Resume = ""
	set Resume = $g(%request.Data("CheckResume",1))
	
	//set ^zjb("InsEstado",0)=" 0 Printed "_Printed_" Payed "_Payed_" Resume "_Resume
	
	set tId = "", tObjId = "" , tText3 = "",  tText4 = "", tFinalText = ""
	
	
	set tId = $g(pRS.Data("ID"))
	
	
	if tId '= "" set tObjId = ##class(User.OEOrdItem).%OpenId(tId)
	if tId '= "" set tObjId2 = ##class(User.OEOrdItem2).%OpenId(tId)
	
	
	if $isObject(tObjId)
	{
		
		set tPhyQty = ""
		set tPhyQty = tObjId.OEORIPhQtyOrd
		
		set tFinalTextERP = ""
		set tFinalTextDIS = ""
		set tERPText4=""
		set tERPText3=""
		
		set tDISText4=""
		set tDISText3=""
		
		set tNroDoc = ""
		set tNroDoc = tObjId.OEORIPrescNo
		if tNroDoc = ""
		{
			set tNroDoc = tObjId.OEORILabEpisodeNo
		}
		
		if tNroDoc = ""
		{
			set tNroDoc = tObjId.OEORIBBExtCode
		}
		
		set tText4 = tObjId.OEORIText4
		set tText3 = tObjId.OEORIText3
		
		set tERPText4=$piece(tText4,"-DIS-",1)
		set tDISText4=$piece(tText4,"-DIS-",2)
		
		set tERPText3=$piece(tText3,"-DIS-",1)
		set tDISText3=$piece(tText3,"-DIS-",2)
		
		
		if tERPText4 = ""
		{
			set tFinalTextERP = "ERP: No Enviado"
		}
		elseif tERPText4 = "E" 
		{
			
			if tERPText3 '= "" 
			{
				set tUser = $p(tERPText3,";",2), tDate = $p(tERPText3,";",3), tTime = $p(tERPText3,";",4)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				if tNroDoc '= ""
				{
					set tFinalTextERP = "Enviado a ERP: "_tUser_" Fecha: "_tDate_" "_tTime
				}
				else
				{
					set tFinalTextERP = "Enviado a ERP: "_tUser_" Fecha: "_tDate_" "_tTime
				}
			}
			
			
		}
		elseif tERPText4 = "ERR" 
		{
			if tERPText3 '= "" 
			{
				 //1 Tipo Mov;2 NroReceta/Docto;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 Fecha ($h); 10 Hora($h);11 Cod Usuario, 12 Error
				
				set tUser = $p(tERPText3,"(;)",11), tDate = $p(tERPText3,"(;)",9), tTime = $p(tERPText3,"(;)",10)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tError = $p(tERPText3,"(;)",12)
				set tTipoMov = $p(tERPText3,"(;)",1)
				set tTipoDesc =""
				if tTipoMov = "S002" set tTipoDesc = "Dispensación"
				if tTipoMov = "S003" set tTipoDesc = "Devolución"
				if tTipoMov = "S004" set tTipoDesc = "Merma" 
				if tTipoDesc = ""
				{				
					set tFinalTextERP = "Error ERP Integracion. Usuario: "_tUser_" Fecha: "_tDate_" "_tTime_". Det: "_tError
				}
				else
				{
					set tFinalTextERP = "Error ERP Tipo: "_tTipoDesc_". Usuario "_tUser_" Fecha: "_tDate_" "_tTime_". Det: "_tError
				}
			}
			
			
		}
		elseif tERPText4 = "D" 
		{
	
			if tERPText3 '= "" 
			{
				set tUser = $p(tERPText3,";",2), tDate = $p(tERPText3,";",3), tTime = $p(tERPText3,";",4)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tFinalTextERP = "Despachado por Usuario: "_tUser_" Cant. Solicitado "_$p(tERPText3,";",5)_" Despachado "_$p(tERPText3,";",6)_" Fecha: "_tDate_" "_tTime
			}
			
			
		}
	
	/////Dispensadores
		
		if tDISText4 = ""
		{
			set tFinalTextDIS = "Kardex/Omnicell: No Enviado"
		}
		elseif tDISText4 = "E" 
		{
			
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",2), tTime = $p(tDISText3,";",3)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				if tNroDoc '= ""
				{
					set tFinalTextDIS = "Enviado a Kardex/Omnicell: "_tUser_" Fecha: "_tDate_" "_tTime
				}
				else
				{
					set tFinalTextDIS = "Enviado a  Kardex/Omnicell "_tUser_" Fecha: "_tDate_" "_tTime
				}
			}
			
			
		}
		elseif tDISText4 = "ER" 
		{
			set tDISText3 = tObjId.OEORIText3
			if tDISText3 '= "" 
			{
				set tError = $p(tDISText3,"[",1)
								
				set tFinalTextDIS = "Error DIS Integracion: "_tError
			}
			
			
		}
		elseif tDISText4 = "D"
		{
	
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",4), tTime = $p(tDISText3,";",5)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tDetalle = " Total: "_$p(tDISText3,";",2)_" Dispensado "_$p(tDISText3,";",3)
				set tMayorDisp = ""
				set tMayorDisp = $p(tDISText3,";",6)
				
				set tFinalTextDIS = "Dispensado por Usuario: "_tUser_tDetalle_" Fecha: "_tDate_" "_tTime
				
				if tMayorDisp '= "" set tFinalTextDIS = "Dispensado por Usuario: "_tUser_tDetalle_" Fecha: "_tDate_" "_tTime_" ERR: Se ha dispensado "_tMayorDisp_" unidades más que lo solicitado"
			}
			
			
		}
		elseif tDISText4 = "DP"
		{	//set ^zjb("Disp",tId,2)= "2 "_tDISText4_" tDISText3 "_tDISText3
	
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",4), tTime = $p(tDISText3,";",5)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tDetalle = " Total: "_$p(tDISText3,";",2)_" Dispensado "_$p(tDISText3,";",3)
				
				set tFinalTextDIS = "Dispensado por Usuario: "_tUser_tDetalle_" Fecha: "_tDate_" "_tTime
			}
			
			
		}
		elseif tDISText4 = "NS"
		{	//set ^zjb("Disp",tId,2)= "2 "_tDISText4_" tDISText3 "_tDISText3
	
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",4), tTime = $p(tDISText3,";",5)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tDetalle = " No hay sufuciente Stock Disponible en Bodega. Requerido: "_$p(tDISText3,";",2)_" Disponible: "_$p(tDISText3,";",3)
				
				set tFinalTextDIS = "Error DIS Integracion: "_tDetalle_" Fecha: "_tDate_" "_tTime
			}
			
			
		}
	}
	//Datos de Impresión Custom
	set tImpresion = ""
	set tImpresion = tObjId2.ITM2ExternalPaperPrescNo
	if (Printed = "on") && (tImpresion'="") 
	{
		Quit 0
	}
	
	if tImpresion '= ""
	{
		set tUsr = $piece(tImpresion,";",1)
		set tDate = $piece(tImpresion,";",2)
		set tTime = $piece(tDate,",",2)
		set tDate = $piece(tDate,",",1)
		
		if tDate '= "" set tDate = $zd(tDate,4)
		if tTime '= "" set tTime = $zt(tTime,1)
		
		set tImpresion = "Usr: "_tUsr_" Fecha "_tDate_" "_tTime
	}
	else
	{
		set tImpresion = "No Impreso"
	}
	
	//Datos de Pago de ERP Custom
	set (tPago,tPagoInicial) = ""
	set tPago = tObjId2.ITM2OverrideOrderLineName
	set tPagoInicial = tObjId2.ITM2OverrideOrderLineName
	//if $get(tId)="2222196||1" set ^zjb("tPago",1)=tPago
	
	if tPago '= ""
	{
		set tPago = $piece(tPago,"||",2)

	}	
	
	if (Payed = "on") && (tPago ="") 
	{
		Quit 0
	}
	
	
	//if $get(tId)="2222196||1" set ^zjb("tPago",2)=tPago
		
	if (tPago = "") && (tPagoInicial'="")
	{
		//if $get(tId)="2222196||1" set ^zjb("tPago",3)=tPago
		set tPago = $piece(tPagoInicial,"||",1)
		//if $get(tId)="2222196||1" set ^zjb("tPago",4)=tPago
	}
	
	if tPago '= ""
	{
		//set tPago = $piece(tPago,"||",2)
		set tTipoMovERP = $piece(tPago,";",1)
		if tTipoMovERP = "E" 
		{
			set tERPAction = "Enviado a ERP: "
			set tUserEnvio = $piece(tPago,";",2)
			set tDate = $piece(tPago,";",3)
			set tTime = $piece(tDate,",",2)
			set tDate = $piece(tDate,",",1)
		
			if tDate '= "" set tDate = $zd(tDate,4)
			if tTime '= "" set tTime = $zt(tTime,1)
			
			set tPago = tERPAction_"Usr "_tUserEnvio_" "_tDate_" "_tTime
		
		}
		else
		{
			if tTipoMovERP = "P" set tERPAction = "Pagado: "
			if tTipoMovERP = "AN" set tERPAction = "Anulado: "
			set tDate = $piece(tPago,";",2)
			set tTime = $piece(tDate,",",2)
			set tDate = $piece(tDate,",",1)
		
			if tDate '= "" set tDate = $zd(tDate,4)
			if tTime '= "" set tTime = $zt(tTime,1)
			
			set tPago = tERPAction_tDate_" "_tTime
		}
		
		
	}
	
	
	set pRS.Data("ExtPaperPrescNo") = tImpresion
	set pRS.Data("PAPMIName7") = tFinalTextERP
	set pRS.Data("PAPMIName5") = tFinalTextDIS
	set pRS.Data("PAPMIName8") = tPhyQty
	set pRS.Data("PAPMIName6") = tNroDoc
	
	if tPago = "" set tPago = "No Enviado a ERP"
	set pRS.Data("PAPMIName4") = tPago
	
	quit 1
}

ClassMethod StockMasterRequestBefore(pMsg As websys.Message) As %String
{
	
	Set tSC = $System.Status.OK()
	Try
	{
		
		set tId = $g(%request.Data("ID",1))
		if tId'= "" set tObjStockItem = ##class(User.INCItm).%OpenId(tId)
		if $IsObject(tObjStockItem) 
		{
			set tActive =""
			set tActive= tObjStockItem.INCIFlag1
			if tActive = "" set tActive = "N"
			
			set ^flagInventoryActiveERP(tId)=tActive
			
		}

		//set ^zjb("ItemMast",1)= "1 "_$get(^flagInventoryActiveERP(tId))
		
		set tUpdateType = $g(%request.Data("TEVENT",1))
		
		if tUpdateType = "d3833iupdate1"
		{
			if $get(%request.Data("TOVERRIDE",1)) = ""
			{
			
				///Codigo Item
				set tCodItemERP = ""
				set tItemOrdenId = $g(%request.Data("INCIOriginalARCIMDRID",1))
				
				if tItemOrdenId '= ""
				{
					set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
					set tLocalHomologacionERP = "SAP"
					if tLocalHomologacionERP '=""
					{
						set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
						set tCodItemERP = ..GetItemExtCodeByLoc(tItemOrdenId,tERPLocationId)
			
						//set ^zjb("CodItem",1)= "1 "_tCodItemERP
					
					}
				}
				else
				{
					set tCodItemERP = $g(%request.Data("INCIText1",1))
				}
				
			
		
				if tCodItemERP = ""
				{
					Do pMsg.AddItem("W"," Alerta "," Código ERP es igual al Código del Item de Stock ") 
				}
			
				set tActive = $g(%request.Data("INCIFlag1",1))
			
				//set ^zjb("ItemMast",31)= "31 tActive "_tActive_" tSC "_tSC
			
				if tActive'= "on"
				{
					set tActive = "N"
					Do pMsg.AddItem("W"," Alerta "," Está ingresando un árticulo en estado Inactivo ") 
				}
	
			}
		}
	}
	Catch (tException)
	{
		Set tSC = tException.AsStatus()
		//set ^zjb("aca",4)="aca 4 tSC "_tSC
		Set bRet=0
	}
	
	
	Quit "1"
}

ClassMethod StockExecutionToERP(pListItemExec As %String) As %String
{
	Try
	{
		//set ^zjb("Exec",1)="1 pListItemExec "_pListItemExec
		if pListItemExec = "" quit
		
		set tOrderExeIDs = $LFS(pListItemExec,"^")
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
			//Salir si no está activa la integracion
		//if 'tIntegrationOn Quit		
			
		//set ^zjb("Exec",2)="2 tOrderExeIDs "_tOrderExeIDs
		
		&SQL(Declare BodegasExecToERP Cursor For
			select distinct DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,DSP_OEORE_ParRef->OEORE_OEORI_ParRef->OEORI_OEORD_ParRef->OEORD_Adm_DR
			into :tBodegaExec, :tAdmExecId
			from SQLUser.OE_Dispensing 
			where DSP_OEORE_ParRef %inlist :tOrderExeIDs
			  and DSP_Status in ('P','C')
			  and DSP_ReturnQty is null
			  and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR->CTLOC_PagerNo is not null
			  and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR->CTLOC_ExternalInfoSystem = 'TRPG'
			)
		
		&SQL(Open BodegasExecToERP)
		&SQL(Fetch BodegasExecToERP)
		
		while(SQLCODE=0)
		{
			////////////Inicio
			
			/////Encabezado
			
			//set ^zjb("Exec",3)="3 tBodegaExec "_tBodegaExec_" tAdmExecId "_tAdmExecId
			set tObjAdm = ##class(User.PAAdm).%OpenId(tAdmExecId)
			
			Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set StockUpdateMsg.MovementCode = "S002"
			Set StockUpdateMsg.User = $g(%session.Data("LOGON.USERCODE"))
				//Set StockUpdateMsg.DocumentNo = tObjExecution.OEOREOEORIParRef.OEORIPrescNo
			Set StockUpdateMsg.Episode = tObjAdm.PAADMADMNo
			Set StockUpdateMsg.PatientLocation = tObjAdm.PAADMCurrentBedDR.BEDCode
			
			Set tLocal = tBodegaExec
			Set tObjLocal = ##class(User.CTLoc).%OpenId(tLocal)
			Set StockUpdateMsg.LocationCode = tObjLocal.CTLOCPagerNo
			Set StockUpdateMsg.FacilityCode = "1000" 
			
			set tObjPatient = tObjAdm.PAADMPAPMIDR.PAPMIRowId
			
			set PAADMPAPMIDR = tObjAdm.PAADMPAPMIDR.%Id()
			
			set (tRtMastId,tFicha) = ""
			set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
			if tRtMastId '= ""
			{
				set tFicha = $piece(^RT(tRtMastId),"^",1)
			}
			
			Set StockUpdateMsg.PatientName = tFicha_"/"_tObjPatient.PAPERID_"/"_tObjPatient.PAPERName2_" "_tObjPatient.PAPERName
			
			set tconta = 1
						
			&SQL(Declare DispExec Cursor For
				select sum(DSP_Qty), DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
				DSP_INCLB_DR->INCLB_INCIB_DR, 
				DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
				DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,
				DSP_OEORE_ParRef->OEORE_OEORI_ParRef
				into :tQty, :tINCIBExpDate, :tINCIBNo, :tINCIId, :tINCILCTLOCDR,:tOrdId
				from SQLUser.OE_Dispensing 
				where DSP_OEORE_ParRef %inlist :tOrderExeIDs
				  and DSP_Status in ('P','C')
				  and DSP_ReturnQty is null
			 	 and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR->CTLOC_PagerNo is not null
			 	 and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR=:tBodegaExec
			  	 and DSP_OEORE_ParRef->OEORE_OEORI_ParRef->OEORI_OEORD_ParRef->OEORD_Adm_DR = :tAdmExecId
				group by DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
				DSP_INCLB_DR->INCLB_INCIB_DR, 
				DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
				DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,
				DSP_OEORE_ParRef->OEORE_OEORI_ParRef
				)
			
		
			&SQL(Open DispExec)
			&SQL(Fetch DispExec)
		
			while(SQLCODE=0)
			{
				if tconta = 1
				{
					set tObjOrder = ##class(User.OEOrdItem).%OpenId(tOrdId)
					
					Set StockUpdateMsg.DocumentNo = tObjOrder.OEORIPrescNo
				}
				
				//set ^zjb("Exec",6,tOrdId)="6 tOrdId "_tOrdId_" tINCILCTLOCDR "_tINCILCTLOCDR_" cod SAP "_tObjLocal.CTLOCPagerNo_" Local "_tObjLocal.CTLOCDesc_" tQty "_tQty
			
				Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
				set tObjBatch = ##class(User.INCItmBat).%OpenId(tINCIBNo)
				set tBatchNumber = tObjBatch.INCIBNo
				if tBatchNumber '= ""
				{
					Set StockItem.BatchNumber = $p(tBatchNumber,";",1)
				}
				if tINCIBExpDate '= ""
				{
					Set StockItem.ExpiryDate = $zd(tINCIBExpDate,8)
				}
				
				Set LocCode = $Piece(^CTLOC(tINCILCTLOCDR),"^",1)
				Set StockItem.Quantity = tQty
				
				
				///Codigo Item
				set tCodERP = ..GetItemCodeERP(tINCIId)
				
				Set StockItem.StockItemCode = tCodERP
				
				Do StockUpdateMsg.Items.Insert(StockItem)
				
				set tconta = tconta +1
					
				&SQL(Fetch DispExec)
			}
			&SQL(Close DispExec)
			
			
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			set tWSSend.Timeout = 300
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			Set tSC = tWSSend.SendEvent(StockUpdateMsg,	.pResponse)
		
			if pResponse.ERPResponse.ErrorDescription '= "" //set ^zjb("EnviaConsulta",9)="9 "_pResponse.ERPResponse.ErrorDescription
			
			
			
			///////////////////////Fin
		
			&SQL(Fetch BodegasExecToERP)
		}
		&SQL(Close BodegasExecToERP)
		
		
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			
		}
		Else
		{
			Set tSC =  tException.AsStatus()
		}
	}
	
	//set ^zjb("Exec",8)="8 tSC "_tSC
	Quit 1
}

ClassMethod AddNroOrderIntegrated(OrderIds) As %Status
{
	Set tSC = $$$OK
	//set ^zjb("AddNro",1)="1 "_OrderIds
	
	if OrderIds = "" Quit tSC
	Try
	{
		set ind = 1
		set tId = $piece($piece(OrderIds,"^",ind),"*",2)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		
		while tId '=""
		{	
			//set ^zjb("AddNro",1)="1 "_tId
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			set tObjOrder2 = ##class(User.OEOrdItem2).%OpenId(tId)
			//set ^zjb("AddNro",2)="2 "_tObjOrder
			set tAdmId = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.%Id()
			//set ^zjb("AddNro",3)="3 "_'$IsObject(tObjOrder)
			if '$IsObject(tObjOrder) Quit
			if '$IsObject(tObjOrder2) Quit
			
			if InsCount = 1
			{
				//set ^zjb("AddNro",7)="7 InsCount "_InsCount
				if $get(^OrderCounterERP)=""
				{
					set ^OrderCounterERP = 1
				}
				else
				{
					set ^OrderCounterERP = ^OrderCounterERP+1
				}
			
				set tNroOrder = "ORD"_$tr($j(^OrderCounterERP,8)," ",0)	
				set InsCount =  InsCount + 1
			}
			
			set InsCount =  InsCount + 1
			
			set tObjOrder.OEORIBBExtCode = tNroOrder
			set tObjOrder.OEORIText3 = ""
			set tObjOrder.OEORIText4 = ""
			
			//Impresion
			set tObjOrder2.ITM2YesNo5 = ""
			set tObjOrder2.ITM2ExternalPaperPrescNo = ""
			
						   
			
			//set ^zjb("AddNro",8)="8 tNroOrder "_tNroOrder_" obj "_tObjOrder.OEORIOEORIDR 
			set tObjVinculado = ""
			set tItemVinculado = ""
			
			//set ^zjb("AddNro","8.1")="8.1 tNroOrder "_tNroOrder_" obj "_tObjOrder.OEORIOEORIDR 
			
			if ($IsObject(tObjOrder.OEORIOEORIDR))
			{
				set tObjVinculado = tObjOrder.OEORIOEORIDR
				set tItemVinculado = tObjVinculado.%Id()
				//set ^zjb("AddNro",9)="9 tItemVinculado "_tItemVinculado
				set tDateVinculado = tObjVinculado.OEORISttDat
				set tTimeVinculado = tObjVinculado.OEORISttTim
				set tFinDate =  tObjVinculado.OEORIEndDate
				set tFinTime =  tObjVinculado.OEORIEndTime
					
				set tObjOrder.OEORISttDat = tDateVinculado
				set tObjOrder.OEORISttTim = tTimeVinculado
					
				set tObjOrder.OEORIEndDate = tFinDate
				set tObjOrder.OEORIEndTime = tFinTime
			}
			
			do tObjOrder.%Save()
			do tObjOrder2.%Save()
			
			if tItemVinculado '=""
			{
				//set ^zjb("AddNro",12)="12 tItemVinculado "_tItemVinculado
				set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
				
				set tNroReceta = tObjOrder.OEORIPrescNo
				//set ^zjb("Receta",1)="1 tNroReceta "_tNroReceta
				set tAdmId = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.%Id()
				if tNroReceta '= ""
				{
			
					&sql(select min(OEORI_SttDat), max(OEORI_FinDate)
				 		into :tStartDate, :tEndDate
				 		from SQLUser.OE_OrdItem
				 		where OEORI_OEORD_ParRef->OEORD_Adm_DR = :tAdmId
				   		and OEORI_PrescNo = :tNroReceta
				 		)
					set tPaque1Id = ""	 
					set tPaque1Id = $order(^PAQUE1(0,"PrescNo",tNroReceta,""),-1)
					set tObjPaque1 = ""
					if tPaque1Id '= ""
					{
						set tObjPaque1 = ##class(User.PAQue1).%OpenId(tPaque1Id)
						if $IsObject(tObjPaque1)
						{
							if tStartDate '= "" set tObjPaque1.QUE1StartDate = tStartDate
							if tEndDate '= "" set tObjPaque1.QUE1EndDate = tEndDate
					
							do tObjPaque1.%Save()
						}
				
					}
				  
				}	
			
			}
			
			do tObjOrder.%Save()
			
			set ind = ind+1
			set tId = $piece($piece(OrderIds,"^",ind),"*",2)
		}
		
		//Send to ERP Integrated movements
		set tSC = ..LogisticToERP(OrderIds,tAdmId,tNroOrder)
	
				
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		//set ^zjb("AddNro",17)="17 tSC "_tSC
		
	}
		
	Quit tSC
}

ClassMethod SentToERPFromKardex(OrderIds, pQty, pUsuario As %String = "intDisp") As %Status
{
	
	Set tSC = $$$OK
	
	if pUsuario = "" set pUsuario = "intDisp"
	set tUserToSendERP = ""
	if OrderIds = "" Quit tSC
	Try
	{
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		set tgroupId = $i(^HMSDispensacionGroup)
		while tId '=""
		{	
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue
			}
			
			set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
			set tObjToInsert.OrderGroupId = tgroupId
			set tObjToInsert.OrderRef = tObjOrder
			
			//Cantidad
			set tObjToInsert.Cantidad = pQty
			
			//Tipo Movimiento 
			set tObjToInsert.TipoMovimiento = "S002"
				
			//Locales 
			set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
					
			if $IsObject(tObjOrder.OEORIRecDepDR)
			{	
				Set tObjLocal = tObjOrder.OEORIRecDepDR
			}
					
			if $IsObject(tObjLocal)
			{
				Set tLocalERP = tObjLocal.CTLOCPagerNo
				if $IsObject(tObjLocal.CTLOCGLCCCDR)
				{
					set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
				}
					
				set tObjToInsert.LocalTrak = tObjLocal
				set tObjToInsert.LocalCodeERP = tLocalERP
				set tObjToInsert.CentroCosto = tCentroCosto
				set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
			}
				
			//Nro Documento
			set (NroDoumento)=""
			set tNroDocumento = tObjOrder.OEORIPrescNo
			if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
			set tObjToInsert.NroDocumento = tNroDocumento
				
			
			//Usuario
			set tUserToSendERP = ""
			set tUserToSendERP =..GetDispUserToSendERP()
			if tUserToSendERP = ""
			{
				set tUserToSendERP = pUsuario
			}
			set tObjToInsert.Usuario = 	tUserToSendERP
			
			//Episodio
			set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
			//Paciente
			set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
			if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
			{
				set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
				
				Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			}
			
			
			///Datos Item
			set tCodERP = ""
			set tOEORIItmMastDR = tObjOrder.OEORIItmMastDR.%Id()
			set tCodItemMast = tObjOrder.OEORIItmMastDR.ARCIMCode
						
			//Codigo Externo
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
			}
						
			//Si no existe Homologacion se manda el codigo del item
			if tCodERP = "" set tCodERP = tCodItemMast
			set tObjToInsert.CodigoERP = tCodERP
			
										
			set tObjToInsert.Lote = ""
			set tObjToInsert.FecVencimiento = ""
						
			set tObjToInsert.CantIntentos = 0
			set tObjToInsert.EstadoEnvio = "Ingresado"
			set tObjToInsert.ProcIngreso = "SentToERPFromKardex-IntOmn-kdx"
				
			set tSC = tObjToInsert.%Save()	
						
			do ##class(Custom.ERP.StockHandler).UpdateManualStock(tObjOrder.OEORIRecDepDR.%Id(),tObjOrder.OEORIItmMastDR.ARCIMCode,pQty,"-","","")
								
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
	
		if tUserToSendERP = "" set tUserToSendERP = pUsuario
		set tResp = ..EnvioDispToERP("Grupo", "", tgroupId, tUserToSendERP)
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		//set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
		
	//set ^zjb("ItemIns",18)="18 tSC "_tSC	
	Quit tSC
	
	
	/* Codigo anterior
	Set tSC = $$$OK
	
	if pUsuario = "" set pUsuario = "intDisp"
	
	set ^zjb("FromKardex",1)="1 OrderIds "_OrderIds_" pQty "_pQty_" pUsuario "_pUsuario
	
	if OrderIds = "" Quit tSC
	Try
	{
		
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//Salir si no está activa la integracion
		
		
			
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		
		while tId '=""
		{	
			//set ^zjb("ItemIns",1)="1 "_tId
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			
			//Actuaizar stock manual en Trak
			set tNroOrdenERP = ""
			set tNroOrdenERP = tObjOrder.OEORIPrescNo
			if tNroOrdenERP ="" set tNroOrdenERP = tObjOrder.OEORIBBExtCode
			//set ^zjb("ItemIns",2)="2 "_tObjOrder
			set tAdmId = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.%Id()
			//set ^zjb("ItemIns",3)="3 "_'$IsObject(tObjOrder)
			if '$IsObject(tObjOrder) Quit
			//Se Construye una sola vez el Encabezado
			
			//Check si la subcategoria corresponde a Insumos a ERP
			set tSubcategoryCode = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICCommissioning
			set tSubcategoriaType = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrderType
			//set ^zjb("ItemIns",4)="4 tSubcategoryCode "_tSubcategoryCode
			
			//if (tSubcategoryCode '= "") && (tSubcategoryCode = "Y")
			//{
				//set ^zjb("ItemIns",4)="4 "_tSubcategoryCode
				if InsCount = 1 
				{
					//set ^zjb("ItemIns",5)="5 "
					//Facility Code
					//set tIdHospital = $g(%session.Data("LOGON.HOSPID"))
					//set tObjHospital = ##class(User.CTHospital).%OpenId(tIdHospital)
					//set tCodHospital = tObjHospital.HOSPCode
					//set ^zjb("ItemIns",5)="5 "_tCodHospital
					//User Name
					//set tUserName = $g(%session.Data("LOGON.USERNAME"))
				
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroOrdenERP
					
					set tUserToSendERP = ""
					set tUserToSendERP =..GetDispUserToSendERP()
					if tUserToSendERP '= ""
					{
						set tObjSend.User = tUserToSendERP
					}
					else
					{
						set tObjSend.User = pUsuario
					}
					
					set tObjSend.MovementCode = "S002"
					
					//Set tObjSend.FromLocationCode = tObjOrder.OEORIOrdDeptDR.CTLOCDesc
					//Set tObjSend.FromCostCenter = tObjOrder.OEORIOrdDeptDR.CTLOCGLCCCDR.GLCCCCode
					Set tObjSend.PatientLocation = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
					
					set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}	
					
					Set tObjSend.PatientName = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_ tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
					Set tObjSend.Episode = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
					//set ^zjb("ItemIns",6)="6 tObjSend.Episode "_tObjSend.Episode
					Set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCPagerNo
					Set tObjSend.CostCenter = tObjOrder.OEORIRecDepDR.CTLOCGLCCCDR.GLCCCCode
				
					if tObjSend.LocationCode = "" set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCCode
					
					
				}
				
				set InsCount =  InsCount + 1
				set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
				set tItemMasterId = tObjOrder.OEORIItmMastDR.%Id() 
				set tItemMasterCode = tObjOrder.OEORIItmMastDR.ARCIMCode 
				set ^zjb("ItemIns",6)="6 tItemMasterCode "_tItemMasterCode
				//Codigo Externo
				set tCodItemERP = ""
				set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
				set tLocalHomologacionERP = "SAP"
				if tLocalHomologacionERP '=""
				{
					set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
					set tCodItemERP = ..GetItemExtCodeByLoc(tItemMasterId,tERPLocationId)
				}
				set ^zjb("ItemIns",7)="7 tCodItemERP "_tCodItemERP
				if tCodItemERP = "" set tCodItemERP = tItemMasterCode
				
				//set ^zjb("ItemIns",8)="8 tCodItemERP "_tCodItemERP
				
				set tObjSendItem.StockItemCode = tCodItemERP
				
				set tObjSendItem.Quantity = pQty
				set tObjSendItem.SerialNumber = tObjOrder.%Id()
				
				do ##class(Custom.ERP.StockHandler).UpdateManualStock(tObjOrder.OEORIRecDepDR.%Id(),tObjOrder.OEORIItmMastDR.ARCIMCode,pQty,"-","","")
								
				do tObjSend.Items.Insert(tObjSendItem)
			//}
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
		//set ^zjb("ItemIns",11)="11 "_tObjSend.Items.Count()
		
		if 'tIntegrationOn Quit	
		if tObjSend.Items.Count() > 0 
		{
			
			
			// Enviar Mensaje
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			set tWSSend.Timeout = 300
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			//set ^zjb("ItemIns",12)="12 "_tSC
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("ItemIns",13)="13 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			//set ^zjb("ItemIns",14)="14 "_tSC
			Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
			set ^zjb("ItemIns",15)="15 "_tSC
			//if pResponse.ERPResponse.ErrorDescription '= "" 
			//If $System.Status.IsError(tSC) Quit
			
			
			
			
			
			///////Analisis de Respuesta
			
			
			//set ^zjb("ItemIns",15)="15 "_tSC
			if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcion = pResponse.ERPResponse.ErrorDescription
			//If $System.Status.IsError(tSC) Quit
			
			if pResponse.ERPResponse.IsError
			{
				set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
				//Generar Traza para asociar al item de orden en caso de error y volver a enviar
				for i=1:1:tObjSend.Items.Count()
				{	
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tTextError = ""
						if pResponse.ERPResponse.IsError '= "" set tTextError = pResponse.ERPResponse.ErrorDescription
					
						set Resp = "Error al Integrar con ERP: "_tTextError
						set tTextToResend = ""
						 //1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
						//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
						set tTextToResend = tObjSend.MovementCode_"(;)"_tObjSend.DocumentNo_"(;)"_tObjSend.LocationCode_"(;)"_tObjSend.FacilityCode_"(;)"_tObjSend.Items.GetAt(i).StockItemCode_"(;)"_tObjSend.Items.GetAt(i).Quantity
						if tObjSend.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
						if tObjSend.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
						set tTextToResend = tTextToResend_"(;)"_$p($h,",",1)_"(;)"_$p($h,",",2)_"(;)"_tObjSend.User_"(;)"_$extract(tTextError,1,55)
						
						//Actualiza estado de Integración
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tTextToResend,"ERR","ERP",tTextError)
						
						set tTypeInt = ""
						set tTypeInt = ..GetMessageTypeERP(tObjSend.MovementCode)
						
	
						set tMessageError = "Error tipo "_tTypeInt_" al integrarse con ERP para el Item "_tObjSend.Items.GetAt(i).StockItemCode_" del Documento "_tObjSend.DocumentNo						
						
						
					}			
				}
					
			}
			else
			{
				set ^zjb("NoError",1)="1 "_tObjSend.DocumentNo
				for i=1:1:tObjSend.Items.Count()
				{
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tUserIdTrak = "" 
						//$g(%session.Data("LOGON.USERID"))
						
						//if tUserIdTrak = "" set tUserIdTrak = "5851"
						
						
						
						set tDescripcion = tObjSend.DocumentNo_";"_tObjSend.User_";"_$p($h,",",1)_";"_$p($h,",",2)
						
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tDescripcion,"E","ERP","")
						
					}			
				}	
				
			}
			
			
			/////Analisis
			
			
			
			
		}
		
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
		
	set ^zjb("ItemIns",18)="18 tSC "_tSC	
	Quit tSC
	
	*/
}

ClassMethod ValidateTimeUpdate(pItemId As %String, pLocalId As %String, pTypeId As %String, pTimeUpdate As %String = "") As %String
{
	Set tSC = $System.Status.OK()
	Try 
	{
		set tResponse = 0
		
		if pTypeId = "ARCIM"
		{
			if pItemId = "" quit
			set tCurrentINCItm = ""
			set tCurrentINCItm = $order(^INCI(0,"ARCIM_DR",+pItemId,tCurrentINCItm))
			
			if tCurrentINCItm = "" quit
			
		}
		
		if pTypeId = "INCI"
		{
			set tCurrentINCItm = pItemId
			
		}
		
		
		if tCurrentINCItm = "" quit
		
		set tCurrentINCItmLocal=""
		set tCurrentINCItmLocal = $order(^INCI("IL_LOC",pLocalId,tCurrentINCItm,""))
		if tCurrentINCItmLocal = "" quit
		
		 set tDate = ""
		 set tTime = ""
		 
		 set tDate = $piece($piece(^INCI(tCurrentINCItm,"IL",tCurrentINCItmLocal),"^",12),",",1)
		 set tTime = $piece($piece(^INCI(tCurrentINCItm,"IL",tCurrentINCItmLocal),"^",12),",",2)		
	
		 //set ^zjb("time",1)= "1 tDate "_tDate_" tTime "_tTime
		 
		 if (tDate = "") || (tTime="")
		 {
			 set tResponse = 1
			 quit
		 }
		 
		 
		 set tCurrentDate = $piece($h,",",1)
		 set tCurrentTime = $piece($h,",",2)
		 
		 set TotalDays = 0
		 set TotalDays = tCurrentDate - tDate
		 if TotalDays > 0 set TotalDays = TotalDays * 86400 
		 
		 
		 set TotalSecond = ""
		 set TotalSecond = tCurrentTime - tTime
		 
		 
		 //set ^zjb("time",2)="2 TotalDays "_TotalDays_" TotalSecond "_TotalSecond 
		 
		 set tTotalTime = TotalDays + TotalSecond
		 
		 if pTimeUpdate = ""
		 {
			 set pTimeUpdate = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("ERP.StockTimeUpdate")
		 }
		 
		 //set ^zjb("time",2)="2 TotalDays "_TotalDays_" TotalSecond "_TotalSecond_" pTimeUpdate "_pTimeUpdate 
		 
		 if tTotalTime > pTimeUpdate
		 {
			 set tResponse = 1
		 }
		
	} 
	Catch (tException)
	{
		Set tSC = tException.AsStatus()
	}
	
	Quit tResponse
}

ClassMethod UpdateTextResponse(pItemId As %String, pText As %String, pStatus As %String, pType As %String, pTextError As %String = "") As %String
{
	Set tSC = $System.Status.OK()
	Try 
	{
		set tResponse = 1
		
		set tObjOrder = ""
		set tObjOrder = ##class(User.OEOrdItem).%OpenId(pItemId)
		if $IsObject(tObjOrder)
		{
			set tEstado = ""
			set tDescripcion = ""
							
			set tText3 = tObjOrder.OEORIText3
			set tDispDesc = $piece(tText3,"-DIS-",2)
			set tERPDesc  = $piece(tText3,"-DIS-",1)
			
			if pType = "DIS"
			{
				set tDescripcion = tERPDesc_"-DIS-"_pText
			}
			else
			{
				set tDescripcion = pText_"-DIS-"_tDispDesc
			}
														
							
			set tText4 = tObjOrder.OEORIText4
			set tDispEstado = $piece(tText4,"-DIS-",2)
			set tERPEstado = $piece(tText4,"-DIS-",1)
			
			if pType = "DIS"
			{
				set tEstado = tERPEstado_"-DIS-"_pStatus
			}
			else
			{
				set tEstado = pStatus_"-DIS-"_tDispEstado
			}
							
							
			set tObjOrder.OEORIText3 = tDescripcion
			set tObjOrder.OEORIText4 = tEstado
							
			do tObjOrder.%Save()
			
			if (pStatus = "ERR") && ($IsObject(tObjOrder.OEORIRecDepDR))
			{
				set (tMessageError,tItemDescription,tNroDoc,tEpisodeNumber,tPatientName, tLocalDescKardex) = ""
				set tLocalDescKardex = tObjOrder.OEORIRecDepDR.CTLOCDesc
				set tItemDescription = tObjOrder.OEORIItmMastDR.ARCIMDesc
				set tNroDoc = tObjOrder.OEORIPrescNo
				if tNroDoc = ""
				{
					set tNroDoc = tObjOrder.OEORILabEpisodeNo
				}
				if tNroDoc = ""
				{
					set tNroDoc = tObjOrder.OEORIBBExtCode
				}
				set tEpisodeNumber = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				set tPatientName = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_ tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
				
				
				set tMessageError = ""
				set tMessageError = $piece(..GetMessageErrorFromIntegrations(tObjOrder.%Id()),"^",1)
				set tMessageError = tMessageError_" Desde Local/Bodega: "_tLocalDescKardex_" para el Item: "_tItemDescription_" Nro Doc: "_tNroDoc_" Episodio: "_tEpisodeNumber_" Paciente: "_tPatientName_" Detalle Error: "_pTextError
				
				
				do ##class(Custom.ERP.StockHandler).CreateMessageErrorIntegracion(tMessageError,"","",tObjOrder.OEORIRecDepDR.%Id())
				
				//set ^zjb("Updatetext",1)="1 "_pText
				set tObjError = ##class(Custom.User.ERPIntegrationErrors).%New()
				set tObjError.OrderItem = tObjOrder.%Id()
				set tObjError.MovementType = $piece(pText,"(;)",1)
				set tObjError.DocumentNo = $piece(pText,"(;)",2)
				set tObjError.LocationCode = $piece(pText,"(;)",3)
				set tObjError.FacilityCode = $piece(pText,"(;)",4)
				set tObjError.ItemCode = $piece(pText,"(;)",5)
				set tObjError.Quantity = $piece(pText,"(;)",6)
				set tObjError.BatchNumber = $piece(pText,"(;)",7)
				set tObjError.ExpiryDate = $piece(pText,"(;)",8)
				set tObjError.Date = $piece(pText,"(;)",9)
				set tObjError.Time = $piece(pText,"(;)",10)
				set tObjError.UserCode = $piece(pText,"(;)",11)
				set tObjError.TextError = pTextError
				set tObjError.LastDateAttemp =  $p($h,",",1)
				set tObjError.LastTimeAttemp = $p($h,",",2)
				set tObjError.IntegrationType = pType
				
				//set ^zjb("Updatetext",2)="2 "_pText
				
				do tObjError.%Save()
				//set ^zjb("Updatetext",3)="3 "_pText
				
			}
							
							
		}
	} 
	Catch (tException)
	{
		Set tSC = tException.AsStatus()
		//set ^zjb("Updatetext","Err")= "tSC "_tSC
	}
	
	Quit tResponse
}

ClassMethod GetUpdateTimer(pAtive As %String, pLocalDesc As %String = "") As %String
{
	Set tSC = $System.Status.OK()
	Try 
	{
		set tResponse = 0
		if pAtive = "" set tResponse = 0 Quit
		
		if pAtive = "1"
		{
			set tAutomatic = "N"
			if pLocalDesc '= ""
			{
				set tLocalId = ""
				set tLocalId = ##class(web.CTLoc).GetIdFromCodeOrDescription(pLocalDesc)
				
				if tLocalId '= ""
				{
					set tLocalCode =  $piece(^CTLOC(tLocalId),"^",1)
					
					if tLocalCode '= ""
					{
						set tLocalCode = ","_tLocalCode_","
					
						set tListLocales =  ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Locales.ListaDeTrabajo.Automatica")
						set tListLocales = ","_tListLocales_","
					
						if (tListLocales [ tLocalCode )
						{
							set tAutomatic = "Y"
						}
						
					
					}
				}
			}
			
			if tAutomatic = "Y"
			{
				set tSession = ""
				set tSession = %session.SessionId
			
				if $get(^TimerHMSWorkBench(tSession)) = "4"
				{
					set tResponse = 0
				}
				else
				{
					set tResponse = 1
				}

			
				if tSession '="" set ^TimerHMSWorkBench(tSession)=1
			}
			else
			{
				set tResponse = 0
			}
		}
		
		if pAtive = 0
		{
			set tSession = ""
			set tSession = %session.SessionId
			kill ^TimerHMSWorkBench(tSession)
			set tResponse = 1	
		}
		
		if pAtive = "3"
		{
			set tSession = ""
			set tSession = %session.SessionId
			if $data(^TimerHMSWorkBench(tSession))
			{
				set tResponse = 1	
			}
			else
			{
				set tResponse = 0
			}
		}
		if pAtive = "4"
		{
			set tSession = ""
			set tSession = %session.SessionId
			set ^TimerHMSWorkBench(tSession) = "4"
		}
		
	} 
	Catch (tException)
	{
		Set tSC = tException.AsStatus()
	}
	
	Quit tResponse
}

ClassMethod ListEstadoSolicitudes(pRS) As %Integer
{
			
	set tId = $g(%request.Data("ID",1))
	set tPos = $g(pRS.Data("ReqItmid"))
	set tDispatchQty = ""
	
	if (tId '= "") && (tPos'="")
	{
		set tRowId = tId_"||"_tPos
		//set ^zjb("listSol",1,tId,tPos)=  "1 tId "_tId_" tPos "_tPos
		
		set tDispatchQty = ""
		&sql(select DispatchQty into :tDispatchQty
		 from Custom_User.INReqItem
		 where ItemId_DR = :tRowId)
	}	
	
	
	set pRS.Data("Position") = tDispatchQty
	
	
	quit 1
}

ClassMethod ResendToERP(OrderIds) As %String
{
	Set tSC = $$$OK
	Set tResp = "1"
	//set ^zjb("ItemInsReenv",0)="0 "_OrderIds
	
	
	Try
	{
		set tResp = ..EnvioDispToERP("Ind",OrderIds,"",$g(%session.Data("LOGON.USERCODE")))
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		Set tResp = tSC
		//set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
	//set ^zjb("ItemIns",18)="18 tSC "_tSC
	Quit tResp
	
	/* Codigo Anterior
	
	Set tSC = $$$OK
	Set tResp = "1"
	//set ^zjb("ItemInsReenv",0)="0 "_OrderIds
	
	
	Try
	{
		if OrderIds = "" Quit
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	
		
			
		set ind = 1
		set tId = $piece(OrderIds,"^",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		
		while (tId '="") && (tResp = "1")
		{	
			//set ^zjb("ItemInsReenv",1,tId)="1 "_tId
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue	
			}
			
			set tERPStatus = ""
			set tERPText = ""			
			set tText4 = tObjOrder.OEORIText4
			set tText3 = tObjOrder.OEORIText3
		
			set tERPStatus=$piece(tText4,"-DIS-",1)
			set tERPText=$piece(tText3,"-DIS-",1)
			
			if (tERPStatus = "") || (tERPText= "") || (tERPStatus'="ERR")
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				set tResp = "El Item "_tObjOrder.OEORIItmMastDR.ARCIMDesc_" no se encuentra error para reenvio"
				continue
			}
			
			
					
			set tNroOrdenERP = ""
			set tNroOrdenERP = $piece(tERPText,"(;)",2)
			set tAdmId = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.%Id()
			
			
			set tUserName = $g(%session.Data("LOGON.USERNAME"))
				
			set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			set tObjSend.User = $g(%session.Data("LOGON.USERCODE"))
			set tObjSend.FacilityCode = 1000
			set tObjSend.DocumentNo = tNroOrdenERP
			set tObjSend.MovementCode = $piece(tERPText,"(;)",1)
			set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}	
					
			Set tObjSend.PatientName = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			Set tObjSend.Episode = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
			Set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCPagerNo
			Set tObjSend.CostCenter = tObjOrder.OEORIRecDepDR.CTLOCGLCCCDR.GLCCCCode
			Set tObjSend.PatientLocation = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
			if tObjSend.LocationCode = "" set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCCode
			
			
			///Item
			set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
			set tItemMasterId = tObjOrder.OEORIItmMastDR.%Id() 
			set tItemMasterCode = tObjOrder.OEORIItmMastDR.ARCIMCode 
			
			//Codigo Externo
			set tCodItemERP = ""
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodItemERP = ..GetItemExtCodeByLoc(tItemMasterId,tERPLocationId)
			}
			
			if tCodItemERP = "" set tCodItemERP = tItemMasterCode
				
			set tObjSendItem.StockItemCode = tCodItemERP		
			set tObjSendItem.Quantity =   $piece(tERPText,"(;)",6)
			
			set tExpiredDate = ""
			set tBatch = ""
			
			set tBatch = $piece(tERPText,"(;)",7)
			set tExpiredDate = $piece(tERPText,"(;)",8)
			
			if tBatch '= "" set tObjSendItem.BatchNumber = tBatch
			if tExpiredDate '= "" set tObjSendItem.ExpiryDate = tExpiredDate
			
			set tObjSendItem.SerialNumber = tObjOrder.%Id()
				
			do tObjSend.Items.Insert(tObjSendItem)
		
			
			
			if tObjSend.Items.Count() > 0 
			{
				// Enviar Mensaje
				Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
				Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
				set tWSSend.Timeout = 300
			
				//Traer la localización de WS según parametros
				Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
				If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
				//set ^zjb("ItemIns",12)="12 "_tSC
				Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
				//set ^zjb("ItemIns",13)="13 "_tSC
				Quit:$System.Status.IsError(tSC)
		
				Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
				//set ^zjb("ItemIns",14)="14 "_tSC
				Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
				//set ^zjb("ItemIns",15)="15 "_tSC
				if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcion = pResponse.ERPResponse.ErrorDescription
				//If $System.Status.IsError(tSC) Quit
			
				if pResponse.ERPResponse.IsError
				{
					set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
					//Generar Traza para asociar al item de orden en caso de error y volver a enviar
					for i=1:1:tObjSend.Items.Count()
					{	
						set tOrderId = ""
						set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
						if tOrderId '= ""
						{
							set tTextError = ""
							if pResponse.ERPResponse.IsError '= "" set tTextError = pResponse.ERPResponse.ErrorDescription
					
							set tTextToResend = ""
						 	//1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
							//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
							set tTextToResend = tObjSend.MovementCode_"(;)"_tObjSend.DocumentNo_"(;)"_tObjSend.LocationCode_"(;)"_tObjSend.FacilityCode_"(;)"_tObjSend.Items.GetAt(i).StockItemCode_"(;)"_tObjSend.Items.GetAt(i).Quantity
							if tObjSend.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
							if tObjSend.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
							set tTextToResend = tTextToResend_"(;)"_$p($h,",",1)_"(;)"_$p($h,",",2)_"(;)"_$g(%session.Data("LOGON.USERCODE"))_"(;)"_$extract(tTextError,1,55)
						
							//Actualiza estado de Integración
							set tRespUpdate = ..UpdateTextResponse(tOrderId,tTextToResend,"ERR","ERP",tTextError)
						}			
					}
					
				}
				else
				{
					set ^zjb("NoError",1)="1 "_tObjSend.DocumentNo
					for i=1:1:tObjSend.Items.Count()
					{
						set tOrderId = ""
						set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
						if tOrderId '= ""
						{
							set tUserIdTrak = $g(%session.Data("LOGON.USERID"))
						
							if tUserIdTrak = "" set tUserIdTrak = ##class(Custom.HMIL.Bill.Rules.GenericV2016).GetCtaUserId()
						
							set tDescripcion = tObjSend.DocumentNo_";"_$g(%session.Data("LOGON.USERCODE"))_";"_$p($h,",",1)_";"_$p($h,",",2)
						
							set tRespUpdate = ..UpdateTextResponse(tOrderId,tDescripcion,"E","ERP","")
											
						}			
					}	
				
				}
			
			}
			else
			{
				set tResp = "Los Items seleccionados no están en el estado para Reenviar"
			}
				
			
			set ^zjb("ItemInsReenv",2,tId)="2 "_tId
						
			set ind = ind+1
			set tId = $piece(OrderIds,"^",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		Set tResp = tSC
		set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
	set ^zjb("ItemIns",18)="18 tSC "_tSC
	Quit tResp
	*/
}

ClassMethod ResendToERPForzado(OrderIds) As %String
{
	Set tSC = $$$OK
	Set tResp = "1"
	//set ^zjb("ItemInsReenv",0)="0 "_OrderIds
	
	
	Try
	{
		set tResp = ..EnvioDispToERP("Forzado",OrderIds,"",$g(%session.Data("LOGON.USERCODE")))
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		Set tResp = tSC
		//set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
	//set ^zjb("ItemIns",18)="18 tSC "_tSC
	Quit tResp
}

ClassMethod ReturnSuppliesToERP(OrderIds) As %String
{
	set Resp="1"
	Set tSC = $$$OK
	//set ^zjb("ReturnSup",1)="1 "_OrderIds
	
	set tOK = 1
	set tLastLocal = ""
	set tCurrentLocal = "" 
	Try
	{
		if OrderIds = "" Quit
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit	
		
			
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		
		while (tId '="") && (tOK = 1)
		{	
			//set ^zjb("ReturnSup",1,itm)="1 "_tId
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			
			if '$IsObject(tObjOrder) set Resp = "Item ya no existe en la base de Datos", tOK = 0 
			
			set tItemDescription = ""
			set tItemDescription = tObjOrder.OEORIItmMastDR.ARCIMDesc
			
			set tCategory = ""
			set tCategory = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrdCatDR.ORCATCode
			if tCategory '= "INS" set Resp = "El Item: "_tItemDescription_" No Corresponde a un Insumo " , tOK = 0 
			
			set tStatus = ""
			set tStatus = tObjOrder.OEORIItemStatDR.OSTATCode
			
			if tStatus '= "E" set Resp = "El Item: "_tItemDescription_" debe estar en estado Realizado para generar la Devolución " , tOK = 0
			
			set tPaymentStatus = ""
			set tPaymentStatus = tObjOrder.OEORIBilled
			
			if tPaymentStatus = "P" set Resp = "El Item: "_tItemDescription_" No puede ser devuelto, ya está en proceso de cobro " , tOK = 0
			
			set tCurrentLocal = tObjOrder.OEORIRecDepDR.%Id()
			
			if tLastLocal '= ""
			{
				if tLastLocal '= tCurrentLocal set Resp = "No se pueden Devolver Insumos de Distintas Bodegas ", tOK = 0 	
			}
			else
			{
				set tLastLocal = tCurrentLocal
			}
			
			
			set tNroOrdenERP = ""
			set tNroOrdenERP = tObjOrder.OEORIPrescNo
			if tNroOrdenERP ="" set tNroOrdenERP = tObjOrder.OEORIBBExtCode
			//set ^zjb("ItemIns",2)="2 "_tObjOrder
			set tAdmId = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.%Id()
			//set ^zjb("ItemIns",3)="3 "_'$IsObject(tObjOrder)
			if '$IsObject(tObjOrder) Quit
			//Se Construye una sola vez el Encabezado
			
			//Check si la subcategoria corresponde a Insumos a ERP
			set tSubcategoryCode = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICCommissioning
			set tSubcategoriaType = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrderType
			//set ^zjb("ItemIns",4)="4 tSubcategoryCode "_tSubcategoryCode
			
			if (tSubcategoryCode '= "") && (tSubcategoryCode = "Y")
			{
				//set ^zjb("ItemIns",4)="4 "_tSubcategoryCode
				if InsCount = 1 
				{
					//set ^zjb("ItemIns",5)="5 "
					//Facility Code
					//set tIdHospital = $g(%session.Data("LOGON.HOSPID"))
					//set tObjHospital = ##class(User.CTHospital).%OpenId(tIdHospital)
					//set tCodHospital = tObjHospital.HOSPCode
					//set ^zjb("ItemIns",5)="5 "_tCodHospital
					//User Name
					set tUserName = $g(%session.Data("LOGON.USERNAME"))
				
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					set tObjSend.User = $g(%session.Data("LOGON.USERCODE"))
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroOrdenERP
					//set tObjSend.u = tUserName
					set tObjSend.MovementCode = "S003"
					
					//Set tObjSend.FromLocationCode = tObjOrder.OEORIOrdDeptDR.CTLOCDesc
					//Set tObjSend.FromCostCenter = tObjOrder.OEORIOrdDeptDR.CTLOCGLCCCDR.GLCCCCode
					//Set tObjSend.PatientLocation = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
					
					set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}	
					
					Set tObjSend.PatientName = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
					Set tObjSend.Episode = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
					//set ^zjb("ItemIns",6)="6 tObjSend.Episode "_tObjSend.Episode
					Set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCPagerNo
					Set tObjSend.CostCenter = tObjOrder.OEORIRecDepDR.CTLOCGLCCCDR.GLCCCCode
				
					if tObjSend.LocationCode = "" set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCCode
					
					
				}
				
				set InsCount =  InsCount + 1
				set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
				set tItemMasterId = tObjOrder.OEORIItmMastDR.%Id() 
				set tItemMasterCode = tObjOrder.OEORIItmMastDR.ARCIMCode 
				//set ^zjb("ItemIns",6)="6 tItemMasterCode "_tItemMasterCode
				//Codigo Externo
				set tCodItemERP = ""
				set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
				set tLocalHomologacionERP = "SAP"
				if tLocalHomologacionERP '=""
				{
					set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
					set tCodItemERP = ..GetItemExtCodeByLoc(tItemMasterId,tERPLocationId)
				}
				//set ^zjb("ItemIns",7)="7 tCodItemERP "_tCodItemERP
				if tCodItemERP = "" set tCodItemERP = tItemMasterCode
				
				//set ^zjb("ItemIns",8)="8 tCodItemERP "_tCodItemERP
				
				set tObjSendItem.StockItemCode = tCodItemERP
				
				if (tSubcategoriaType = "R") || (tSubcategoriaType = "I")
				{
					//Cantidad
					set tCantidad = 0
					set qty=$piece($get(^OEORD(ord,"I",itm,1)),"^",12)
	 				set uom=$piece($get(^OEORD(ord,"I",itm,2)),"^",3)
	 				set arcim=$piece($get(^OEORD(ord,"I",itm,1)),"^",2)
	 				set drgform=$piece($get(^ARCIM(+arcim,1,1)),"^",12)
		
					set tCantidad = $$calcqty^aOET7(drgform,uom,qty)
					
					set tObjSendItem.Quantity =  tCantidad
				}
				else
				{
					set tObjSendItem.Quantity =  tObjOrder.OEORIPhQtyOrd
				}
				
				set tObjSendItem.SerialNumber = tObjOrder.%Id()
				
				
				
				do tObjSend.Items.Insert(tObjSendItem)
			}
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
		
		if tOK = 0 Quit
		//set ^zjb("ItemIns",11)="11 "_tObjSend.Items.Count()
		if tObjSend.Items.Count() > 0 
		{
			// Enviar Mensaje
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			set tWSSend.Timeout = 300
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			//set ^zjb("ItemIns",12)="12 "_tSC
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("ItemIns",13)="13 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			//set ^zjb("ItemIns",14)="14 "_tSC
			Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
			//set ^zjb("ItemIns",15)="15 "_tSC
			if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcion = pResponse.ERPResponse.ErrorDescription
			//If $System.Status.IsError(tSC) Quit
			
			if pResponse.ERPResponse.IsError
			{
				set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
				//Generar Traza para asociar al item de orden en caso de error y volver a enviar
				for i=1:1:tObjSend.Items.Count()
				{	
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tTextError = ""
						if pResponse.ERPResponse.IsError '= "" set tTextError = pResponse.ERPResponse.ErrorDescription
					
						set Resp = "Error al Integrar con ERP: "_tTextError
						set tTextToResend = ""
						 //1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
						//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
						set tTextToResend = tObjSend.MovementCode_"(;)"_tObjSend.DocumentNo_"(;)"_tObjSend.LocationCode_"(;)"_tObjSend.FacilityCode_"(;)"_tObjSend.Items.GetAt(i).StockItemCode_"(;)"_tObjSend.Items.GetAt(i).Quantity
						if tObjSend.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
						if tObjSend.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
						set tTextToResend = tTextToResend_"(;)"_$p($h,",",1)_"(;)"_$p($h,",",2)_"(;)"_$g(%session.Data("LOGON.USERCODE"))_"(;)"_$extract(tTextError,1,55)
						
						//Actualiza estado de Integración
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tTextToResend,"ERR","ERP",tTextError)
						
					
					}			
				}
					
			}
			else
			{
				//set ^zjb("NoError",1)="1 "_tObjSend.DocumentNo
				for i=1:1:tObjSend.Items.Count()
				{
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tUserIdTrak = $g(%session.Data("LOGON.USERID"))
						
						if tUserIdTrak = "" set tUserIdTrak = ##class(Custom.HMIL.Bill.Rules.GenericV2016).GetCtaUserId()
						
						
						
						set tDescripcion = tObjSend.DocumentNo_";"_$g(%session.Data("LOGON.USERCODE"))_";"_$p($h,",",1)_";"_$p($h,",",2)
						
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tDescripcion,"E","ERP","")
						
						do ChangeStatus^COEOrdItem5(tOrderId,"D",tUserIdTrak,"","")
					}			
				}	
				
			}
			
		}
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		//set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
	//set ^zjb("ItemIns",18)="18 tSC "_tSC
	Quit Resp
}

ClassMethod CreateMessageErrorIntegracion(pMessage As %String, pUserCode As %String = "", pListUserRecipient As %String = "", pLocalId As %String = "") As %String
{
	Set tSC = $$$OK
	Set tResp = "1"
	Try
	{
		if pMessage = "" Quit
		
		if pUserCode = ""
		{
			set pUserCode = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Message.IntegrationCode.User")
			
			if pUserCode = "" quit
			
			set tIdUser =""
			&sql(select %id
				into :tIdUser
				from SQLUser.SS_User 
				where SSUSR_Initials = :pUserCode)
				
			if tIdUser = "" quit
				
			set tObjUser = ""
			set tObjUser = ##class(User.SSUser).%OpenId(tIdUser)
			if '$IsObject(tObjUser) quit
			
			if pListUserRecipient '= ""
			{
				set tobjMessage = ##class(User.SSMessage).%New()
				do tobjMessage.MESSMessage.Insert(pMessage)
				set tobjMessage.MESSUserCreatedDR = tObjUser
				set tobjMessage.MESSDateCreated = $p($h,",",1)
				set tobjMessage.MESSTimeCreated = $p($h,",",2)
				do tobjMessage.%Save()
				
				set tIdNewMessage = tobjMessage.%Id()
				
				if tIdNewMessage = "" quit
				
				set ind = 1
				set tCurrentUser =  $piece(pListUserRecipient,",",ind)
				while tCurrentUser '= ""
				{
					set tIdCurrentUser =""
					&sql(select %id
						into :tIdCurrentUser
						from SQLUser.SS_User 
						where SSUSR_Initials = :tCurrentUser
						)
					
					if SQLCODE '= 0 set tIdCurrentUser=""
					
					if tIdCurrentUser '= ""
					{
						&sql(INSERT INTO SQLUser.SS_MessageRecipient
							(MESSREC_Message_DR,MESSREC_User_DR)
							 VALUES (:tIdNewMessage,:tIdCurrentUser)
							)
					}
					
					set ind = ind +1
					set tCurrentUser =  $piece(pListUserRecipient,",",ind)
					
				}
			}
			else
			{
				//////Inicio
						
				set tListUsuariosId = ""
				if pLocalId '= ""
				{
				
					set tCurrentUserToList = ""
				
					//Usuarios por Defecto
					set tCurrentUserToList= $order(^SSU("SSUSR",0,"DefDep",pLocalId,tCurrentUserToList))
					while tCurrentUserToList '= ""
					{
						if tListUsuariosId = "" 
						{
							set tListUsuariosId = tCurrentUserToList
						}
						else
						{
							set tListUsuariosId = tListUsuariosId_","_tCurrentUserToList
						}
					
						set tCurrentUserToList= $order(^SSU("SSUSR",0,"DefDep",pLocalId,tCurrentUserToList))
					}
				
					//Usuario en Otros Locales
					&sql(Declare tOtherUserCursor Cursor for
						 select distinct OTHLL_ParRef 
						 into :tCurrentUserToList
					 	from SQLUser.SS_UserOtherLogonLoc
					 	where OTHLL_CTLOC_DR = :pLocalId
					 	)
					 
				
					&SQL(Open tOtherUserCursor)
					&SQL(Fetch tOtherUserCursor)
					while(SQLCODE=0)
					{
						if tListUsuariosId = "" 
						{
							set tListUsuariosId = tCurrentUserToList
						}
						else
						{
							set tListUsuariosId = tListUsuariosId_","_tCurrentUserToList
						}
				
						&SQL(Fetch tOtherUserCursor)
					}
				
					&SQL(Close tOtherUserCursor)
					
					if tListUsuariosId '= ""
					{
						set tobjMessage = ##class(User.SSMessage).%New()
						do tobjMessage.MESSMessage.Insert(pMessage)
						set tobjMessage.MESSUserCreatedDR = tObjUser
						set tobjMessage.MESSDateCreated = $p($h,",",1)
						set tobjMessage.MESSTimeCreated = $p($h,",",2)
						do tobjMessage.%Save()
				
						set tIdNewMessage = tobjMessage.%Id()
				
						if tIdNewMessage = "" quit
				
						set ind = 1
						set tIdCurrentUser =  $piece(tListUsuariosId,",",ind)
						while tIdCurrentUser '= ""
						{
					
							if tIdCurrentUser '= ""
							{
								&sql(INSERT INTO SQLUser.SS_MessageRecipient
									(MESSREC_Message_DR,MESSREC_User_DR)
							 		VALUES (:tIdNewMessage,:tIdCurrentUser)
									)
							}
					
							set ind = ind +1
							set tIdCurrentUser =  $piece(tListUsuariosId,",",ind)
					
						}
					}
			
				}
			
	
			}	
				
				/////Fin
			
		}
		
	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		Set tResp = tSC
		//set ^zjb("Message",17)="17 tSC "_tSC
		
	}
	//set ^zjb("Message",18)="18 tSC "_tSC
	
	Quit tResp
}

ClassMethod GetMessageTypeERP(pType As %String) As %String
{
	Set tSC = $$$OK
	Set tResp = ""
	Try
	{
		if pType = "" Quit
		
		if pType = "S001" set tResp = "Consulta"
		if pType = "S002" set tResp = "Dispensación"
		if pType = "S003" set tResp = "Devolución"
		if pType = "S004" set tResp = "Merma"
		
	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		Set tResp = ""
		
		
	}
	//set ^zjb("Message",18)="18 tSC "_tSC
	
	Quit tResp
}

ClassMethod ListExtraPharmacyData(pRS) As %Integer
{
	//set ^zjb("list",0)="0 "_$get(pRS.Data("OEOrdIDs"))
	
	set tListIds = ""
	set tListIds = $get(pRS.Data("OEOrdIDs"))
	
	if $get(tListIds) = "" quit 1
	Set lOrderIDs = $LFS(tListIds,",")
	
	//set ^zjb("list",1,tListIds)="1"
	
	set tId = $piece(tListIds,",",1)
	if $get(tId) = "" quit 1
	
	//set ^zjb("list",2,tId)="2"
	
	
	if tId '= "" set tObjId = ##class(User.OEOrdItem).%OpenId(tId)
	if tId '= "" set tObjId2 = ##class(User.OEOrdItem2).%OpenId(tId)
	
	
	//Incorporar marca de Impresión de documento
	set tImpresion = ""
	set tImpresion = tObjId2.ITM2ExternalPaperPrescNo
	
	if (tImpresion = "") && ($get(lOrderIDs)'="")
	{
		set contaImpresos = 0
		&sql(select count(*)
			 into :contaImpresos
			from SQLUser.OE_OrdItem2 
			where %id %inlist :lOrderIDs
			  and ITM2_ExternalPaperPrescNo is not null
			)
		if SQLCODE '= 0 set contaImpresos = 0
		
		if contaImpresos > 0
		{
			set tImpresion = "Impreso"
		}
			
	}
	
		
	if tImpresion '= "" 
	{
		set tUsr = $piece(tImpresion,";",1)
		set tDate = $piece(tImpresion,";",2)
		set tTime = $piece(tDate,",",2)
		set tDate = $piece(tDate,",",1)
		
		if tDate '= "" set tDate = $zd(tDate,4)
		if tTime '= "" set tTime = $zt(tTime,1)
		
		set tImpresion = "Usr: "_tUsr_" Fecha "_tDate_" "_tTime
		
		set pRS.Data("PAPMIName5") = tImpresion
					
	}
	else
	{
		set pRS.Data("PAPMIName5")="Sin Impresión"
	}
	
	if $IsObject(tObjId.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
	{
		set tPatMastId = ""
		set tPatMastId = tObjId.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
		set tFicha = ""
		
		if tPatMastId'= ""
		{
			&sql(SELECT top 1 RTMAS_MRNo 
		    	 into :tFicha
		     	 FROM SQLUser.rt_master 
		    	 WHERE RTMAS_PatNo_DR = :tPatMastId
		       	   AND RTMAS_MRType_DR=1
				)
			if SQLCODE '= 0 set tFicha = ""
			
			if tFicha '= ""
			{
				set pRS.Data("MRN")= tFicha
			}
		}
		
		
	}
	
	
	quit 1
}

ClassMethod PackAndExecuteOrderBP(tOrderItemId As %String) As %Status
{
	Set tSC = $System.Status.OK()
	if tOrderItemId = "" Quit tSC
	Try
	{
		
		Set tFactor=##class(Custom.HMIL.Stock.Util).CalcDoseEQ(tOrderItemId)
		Set ord = $Piece(tOrderItemId,"||",1)
		Set itm = $Piece(tOrderItemId,"||",2)
		
		Set ItmMastId=$piece($get(^OEORD(ord,"I",itm,1)),"^",2)			
		Set qty=$piece($get(^OEORD(ord,"I",itm,1)),"^",12)
		Set uom=$piece($get(^OEORD(ord,"I",itm,2)),"^",3)
		Set drgform=$piece($get(^ARCIM(+ItmMastId,1,1)),"^",12)
		if drgform '= "" 
		{
			Set tPending = +$$calcqty^aOET7(drgform,uom,qty)
		}
		else
		{
			Set tPending = qty
		}
		
		set tDispensedLeft = tPending
		set tPending = tPending*tFactor
		
		
		
		set tLastRowExecId = ""
		&SQL(DECLARE ctExecItems CURSOR FOR
		  	 Select %NOLOCK %ID, OEORE_PhQtyOrd INTO :tOEOrdExecID, :tOrderQty
			 From SQLUser.OE_OrdExec
			 where OEORE_OEORI_ParRef = :tOrderItemId
			 )
		
		&SQL(OPEN ctExecItems)
		&SQL(FETCH ctExecItems)
		while(SQLCODE=0)
		{
			set pDispensed = 0
			set tLastRowExecId = tOEOrdExecID
			set pDispensed = ##class(Custom.HMIL.Stock.Util).CalcCurrentDispByExec(tOEOrdExecID)
			set tDisponible = tOrderQty - pDispensed
			//set ^zjb("RecBP","1.2",tOEOrdExecID)="1.2 tDisponible "_tDisponible_" tOrderQty "_tOrderQty_" pDispensed "_pDispensed_" tPending "_tPending
			If ((tDisponible>0)&&(tPending>0))
			{
				if (tPending < tDisponible) && (tPending>0)
				{
					set tDisponible = tPending
				}	
								
				if (tDisponible > 0)
				{	
					set tDispensing = ""					
					if tFactor'= 0 
					{
						set tDispensing = $FNUMBER((tDisponible/tFactor),"",12)
						set tDispensedLeft = tDispensedLeft-tDispensing
					}
					//set ^zjb("RecBP","1.3",tOEOrdExecID)="1.3 tOEOrdExecID "_tOEOrdExecID_" tDispensing "_tDispensing
					set tUserId = $g(%session.Data("LOGON.USERCODE"))
					
					&sql(Update SQLUser.OE_OrdExec
					     set OEORE_CTPCP_DR = :tUserId,
					     	 OEORE_Order_Status_DR=1,
					     	 OEORE_DateExecuted = CURRENT_DATE,
					     	 OEORE_TimeExecuted = CURRENT_TIME,
					     	 OEORE_QtyAdmin = :tOrderQty
						where %id = :tOEOrdExecID
						)
					
					Set tSC = ##class(Custom.Kardex.Orders).PharmExecute(tOrderItemId, tOEOrdExecID, tDispensing, $g(%session.Data("LOGON.USERCODE")))
				}
								
								
				//Set tDispensed = tDispensed + tDispensing
				Set tPending = tPending - tDisponible
				
			}
			&SQL(FETCH ctExecItems)
		}
		&SQL(CLOSE ctExecItems)
		
		if (tPending > 0) && (tLastRowExecId'="") && (tDispensedLeft>0)
		{
			set tDispensing = ""					
			set tDispensing = tDispensedLeft
			//set ^zjb("Receive","1.3",tOEOrdExecID)="1.3 tOEOrdExecID "_tOEOrdExecID_" tDispensing "_tDispensing
			set tSC = ##class(Custom.Kardex.Orders).PharmExecute(tOrderItemId, tLastRowExecId, tDispensing, $g(%session.Data("LOGON.USERCODE")))
		}
	
	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		//set ^zjb("RecBP",17)="17 tSC "_tSC
		
	}
	//set ^zjb("RecBP",18)="18 tSC "_tSC
	Quit tSC
}

ClassMethod StockReturnOmnicell(pListDispense As %String) As %String
{
	Try
	{
		//set ^zjb("ReturnOmnicellERP",1)="1 pListDispense "_pListDispense
		if pListDispense = "" quit
		
		set tOrderDispense = $LFS(pListDispense,",")
			
		//set ^zjb("ReturnOmnicellERP",2)="2 tOrderDispense "_tOrderDispense
		
		set tgroupId = $i(^HMSDispensacionGroup)
		
		&SQL(Declare BodegasReturnOmnicellToERP Cursor For
			select distinct DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,DSP_OEORE_ParRef->OEORE_OEORI_ParRef->OEORI_OEORD_ParRef->OEORD_Adm_DR
			into :tBodegaExec, :tAdmExecId
			from SQLUser.OE_Dispensing 
			where %id %inlist :tOrderDispense
			  and DSP_ReturnQty is not null
			  and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR->CTLOC_PagerNo is not null
			  and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR->CTLOC_ExternalInfoSystem = 'GENERIC'
			)
		
		&SQL(Open BodegasReturnOmnicellToERP)
		&SQL(Fetch BodegasReturnOmnicellToERP)
		
		while(SQLCODE=0)
		{
			/////Encabezado

						
			&SQL(Declare DispReturnExec Cursor For
				select sum(DSP_ReturnQty), 
				DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
				DSP_INCLB_DR->INCLB_INCIB_DR, 
				DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
				DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,
				DSP_OEORE_ParRef->OEORE_OEORI_ParRef
				into :tQty, :tINCIBExpDate, :tINCIBNo, :tINCIId, :tINCILCTLOCDR,:tOrdId
				from SQLUser.OE_Dispensing 
				where %id %inlist :tOrderDispense
				  and DSP_ReturnQty is not null
			 	 and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR->CTLOC_PagerNo is not null
			 	 and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR=:tBodegaExec
			  	 and DSP_OEORE_ParRef->OEORE_OEORI_ParRef->OEORI_OEORD_ParRef->OEORD_Adm_DR = :tAdmExecId
				group by DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
				DSP_INCLB_DR->INCLB_INCIB_DR, 
				DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
				DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,
				DSP_OEORE_ParRef->OEORE_OEORI_ParRef
				)
			
		
			&SQL(Open DispReturnExec)
			&SQL(Fetch DispReturnExec)
		
			while(SQLCODE=0)
			{
				set tObjOrder = ##class(User.OEOrdItem).%OpenId(tOrdId)
					
				if '$IsObject(tObjOrder)
				{
					&SQL(Fetch DispReturnExec)
					continue
				}
				
				set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
				set tObjToInsert.OrderGroupId = tgroupId
				set tObjToInsert.OrderRef = tObjOrder
			
				//Cantidad
				set tObjToInsert.Cantidad = tQty
			
				//Tipo Movimiento 
				set tObjToInsert.TipoMovimiento = "S003"
				
				//Locales 
				set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
					
				if $IsObject(tObjOrder.OEORIRecDepDR)
				{	
					Set tObjLocal = tObjOrder.OEORIRecDepDR
				}
					
				if $IsObject(tObjLocal)
				{
					Set tLocalERP = tObjLocal.CTLOCPagerNo
					if $IsObject(tObjLocal.CTLOCGLCCCDR)
					{
						set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
					}
					
					set tObjToInsert.LocalTrak = tObjLocal
					set tObjToInsert.LocalCodeERP = tLocalERP
					set tObjToInsert.CentroCosto = tCentroCosto
					set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
				}
				
				//Nro Documento
				set (NroDoumento)=""
				set tNroDocumento = tObjOrder.OEORIPrescNo
				if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
				set tObjToInsert.NroDocumento = tNroDocumento
			
				//Usuario
				set tUserToSendERP = ""
				set tUserToSendERP =..GetDispUserToSendERP()
				if tUserToSendERP = ""
				{
					set tUserToSendERP = "IntDisp"
				}
			
				set tObjToInsert.Usuario = 	tUserToSendERP
			
				//Episodio
				set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
				//Paciente
				set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
				if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
				{
					set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
					set (tRtMastId,tFicha) = ""
					set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
					if tRtMastId '= ""
					{
						set tFicha = $piece(^RT(tRtMastId),"^",1)
					}
				
					Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
				}
			
			
				///Datos Item
				set tCodERP = ""
				set tOEORIItmMastDR = tObjOrder.OEORIItmMastDR.%Id()
				set tCodItemMast = tObjOrder.OEORIItmMastDR.ARCIMCode
						
				//Codigo Externo
				set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
				set tLocalHomologacionERP = "SAP"
				if tLocalHomologacionERP '=""
				{
					set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
					set tCodERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
				}
						
				//Si no existe Homologacion se manda el codigo del item
				if tCodERP = "" set tCodERP = tCodItemMast
				set tObjToInsert.CodigoERP = tCodERP
				
				set (tBatchNumber,tFecVencimiento)=""
				if tINCIBNo '=""
				{
					set tObjBatch = ##class(User.INCItmBat).%OpenId(tINCIBNo)
					if $isObject(tObjBatch)
					{
						set tBatchNumber = tObjBatch.INCIBNo
						if tBatchNumber '= ""
						{
							Set tBatchNumber = $p(tBatchNumber,";",1)
						}
					}
				}
				if tINCIBExpDate '= ""
				{
					set tFecVencimiento = $zd(tINCIBExpDate,8)
				}						
										
										
				set tObjToInsert.Lote = tBatchNumber
				set tObjToInsert.FecVencimiento = tFecVencimiento
						
				set tObjToInsert.CantIntentos = 0
				set tObjToInsert.EstadoEnvio = "Ingresado"
				set tObjToInsert.ProcIngreso = "StockReturnOmnicell-Int Omn"
				
				set tSC = tObjToInsert.%Save()	
										
				do ##class(Custom.ERP.StockHandler).UpdateManualStock(tObjOrder.OEORIRecDepDR.%Id(),tObjOrder.OEORIItmMastDR.ARCIMCode,tQty,"+","","")
				set tResp = ..EnvioDispToERP("Grupo", "", tgroupId, tUserToSendERP)	
					
				&SQL(Fetch DispReturnExec)
			}
			&SQL(Close DispReturnExec)
			
			
			
		
			&SQL(Fetch BodegasReturnOmnicellToERP)
		}
		&SQL(Close BodegasReturnOmnicellToERP)
		
		
		&sql(Update %nolock %notrigger SQLUser.OE_Dispensing
			set DSP_ReturnQty = DSP_TotalReturnedQty
			where %id %inlist :tOrderDispense)
			
			
		
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			
		}
		Else
		{
			Set tSC =  tException.AsStatus()
		}
	}
	
	//set ^zjb("ReturnOmnicellERP","Error")=" tsc "_tSC
	Quit 1
	
	/* Codigo Anterior
	Try
	{
		set ^zjb("ReturnOmnicellERP",1)="1 pListDispense "_pListDispense
		if pListDispense = "" quit
		
		set tOrderDispense = $LFS(pListDispense,",")
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
			//Salir si no está activa la integracion
		//if 'tIntegrationOn Quit		
			
		set ^zjb("ReturnOmnicellERP",2)="2 tOrderDispense "_tOrderDispense
		
		&SQL(Declare BodegasReturnOmnicellToERP Cursor For
			select distinct DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,DSP_OEORE_ParRef->OEORE_OEORI_ParRef->OEORI_OEORD_ParRef->OEORD_Adm_DR
			into :tBodegaExec, :tAdmExecId
			from SQLUser.OE_Dispensing 
			where %id %inlist :tOrderDispense
			  and DSP_ReturnQty is not null
			  and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR->CTLOC_PagerNo is not null
			  and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR->CTLOC_ExternalInfoSystem = 'GENERIC'
			)
		
		&SQL(Open BodegasReturnOmnicellToERP)
		&SQL(Fetch BodegasReturnOmnicellToERP)
		
		while(SQLCODE=0)
		{
			////////////Inicio
			
			/////Encabezado
			
			set ^zjb("Exec",3)="3 tBodegaExec "_tBodegaExec_" tAdmExecId "_tAdmExecId
			set tObjAdm = ##class(User.PAAdm).%OpenId(tAdmExecId)
			
			Set StockUpdateMsg = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set StockUpdateMsg.MovementCode = "S003"
			Set StockUpdateMsg.User = $g(%session.Data("LOGON.USERCODE"))
				//Set StockUpdateMsg.DocumentNo = tObjExecution.OEOREOEORIParRef.OEORIPrescNo
			Set StockUpdateMsg.Episode = tObjAdm.PAADMADMNo
			Set StockUpdateMsg.PatientLocation = tObjAdm.PAADMCurrentBedDR.BEDCode
			
			Set tLocal = tBodegaExec
			Set tObjLocal = ##class(User.CTLoc).%OpenId(tLocal)
			Set StockUpdateMsg.LocationCode = tObjLocal.CTLOCPagerNo
			Set StockUpdateMsg.FacilityCode = "1000" 
			
			set tObjPatient = tObjAdm.PAADMPAPMIDR.PAPMIRowId
			set PAADMPAPMIDR = tObjAdm.PAADMPAPMIDR.%Id()
			
			set (tRtMastId,tFicha) = ""
			set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
			if tRtMastId '= ""
			{
				set tFicha = $piece(^RT(tRtMastId),"^",1)
			}
			
			Set StockUpdateMsg.PatientName = tFicha_"/"_tObjPatient.PAPERID_"/"_tObjPatient.PAPERName2_" "_tObjPatient.PAPERName
			
			set tconta = 1
						
			&SQL(Declare DispReturnExec Cursor For
				select sum(DSP_ReturnQty), DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
				DSP_INCLB_DR->INCLB_INCIB_DR, 
				DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
				DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,
				DSP_OEORE_ParRef->OEORE_OEORI_ParRef
				into :tQty, :tINCIBExpDate, :tINCIBNo, :tINCIId, :tINCILCTLOCDR,:tOrdId
				from SQLUser.OE_Dispensing 
				where %id %inlist :tOrderDispense
				  and DSP_ReturnQty is not null
			 	 and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR->CTLOC_PagerNo is not null
			 	 and DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR=:tBodegaExec
			  	 and DSP_OEORE_ParRef->OEORE_OEORI_ParRef->OEORI_OEORD_ParRef->OEORD_Adm_DR = :tAdmExecId
				group by DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_ExpDate, 
				DSP_INCLB_DR->INCLB_INCIB_DR, 
				DSP_INCLB_DR->INCLB_INCIB_DR->INCIB_INCI_ParRef,
				DSP_INCLB_DR->INCLB_INCIL_ParRef->INCIL_CTLOC_DR,
				DSP_OEORE_ParRef->OEORE_OEORI_ParRef
				)
			
		
			&SQL(Open DispReturnExec)
			&SQL(Fetch DispReturnExec)
		
			while(SQLCODE=0)
			{
				set tObjOrder = ##class(User.OEOrdItem).%OpenId(tOrdId)
					
				Set StockUpdateMsg.DocumentNo = tObjOrder.OEORIPrescNo
			
				
				set ^zjb("Exec",6,tOrdId)="6 tOrdId "_tOrdId_" tINCILCTLOCDR "_tINCILCTLOCDR_" cod SAP "_tObjLocal.CTLOCPagerNo_" Local "_tObjLocal.CTLOCDesc_" tQty "_tQty
			
				Set StockItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
				set tObjBatch = ##class(User.INCItmBat).%OpenId(tINCIBNo)
				set tBatchNumber = tObjBatch.INCIBNo
				if tBatchNumber '= ""
				{
					Set StockItem.BatchNumber = $p(tBatchNumber,";",1)
				}
				if tINCIBExpDate '= ""
				{
					Set StockItem.ExpiryDate = $zd(tINCIBExpDate,8)
				}
				
				Set LocCode = $Piece(^CTLOC(tINCILCTLOCDR),"^",1)
				Set StockItem.Quantity = tQty
				
				
				///Codigo Item
				set tCodERP = ..GetItemCodeERP(tINCIId)
				
				Set StockItem.StockItemCode = tCodERP
				
				//Actualiza en Trak los montos
				do ##class(Custom.ERP.StockHandler).UpdateManualStock(tObjOrder.OEORIRecDepDR.%id(),tObjOrder.OEORIItmMastDR.ARCIMCode,tQty,"+","","")
				
				Do StockUpdateMsg.Items.Insert(StockItem)
				
				set tconta = tconta +1
					
				&SQL(Fetch DispReturnExec)
			}
			&SQL(Close DispReturnExec)
			
			
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			set tWSSend.Timeout = 300
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			Set tSC = tWSSend.SendEvent(StockUpdateMsg,	.pResponse)
		
			if pResponse.ERPResponse.ErrorDescription '= "" set ^zjb("EnviaConsulta",9)="9 "_pResponse.ERPResponse.ErrorDescription
			
			
			
			///////////////////////Fin
		
			&SQL(Fetch BodegasReturnOmnicellToERP)
		}
		&SQL(Close BodegasReturnOmnicellToERP)
		
		
		&sql(Update %nolock %notrigger SQLUser.OE_Dispensing
			set DSP_ReturnQty = DSP_TotalReturnedQty
			where %id %inlist :tOrderDispense)
		
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			
		}
		Else
		{
			Set tSC =  tException.AsStatus()
		}
	}
	
	//set ^zjb("Exec",8)="8 tSC "_tSC
	Quit 1
	
	*/
}

ClassMethod ReturnOmnicellSuppliesToERP(OrderIds, pQty, pUserId) As %String
{
	Set tSC = $$$OK
	set pUsuario = ""
	if pUserId '= "" set pUsuario = $piece(^SSU("SSUSR",pUserId),"^",1)
	if pUsuario = "" set pUsuario = "intDisp"
	set tUserToSendERP = ""
	if OrderIds = "" Quit tSC
	Try
	{
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		set tgroupId = $i(^HMSDispensacionGroup)
		while tId '=""
		{	
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue
			}
			set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
			set tObjToInsert.OrderGroupId = tgroupId
			set tObjToInsert.OrderRef = tObjOrder
			
			//Cantidad
			set tObjToInsert.Cantidad = pQty
			
			//Tipo Movimiento 
			set tObjToInsert.TipoMovimiento = "S003"
				
			//Locales 
			set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
					
			if $IsObject(tObjOrder.OEORIRecDepDR)
			{	
				Set tObjLocal = tObjOrder.OEORIRecDepDR
			}
					
			if $IsObject(tObjLocal)
			{
				Set tLocalERP = tObjLocal.CTLOCPagerNo
				if $IsObject(tObjLocal.CTLOCGLCCCDR)
				{
					set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
				}
					
				set tObjToInsert.LocalTrak = tObjLocal
				set tObjToInsert.LocalCodeERP = tLocalERP
				set tObjToInsert.CentroCosto = tCentroCosto
				set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
			}
				
			//Nro Documento
			set (NroDoumento)=""
			set tNroDocumento = tObjOrder.OEORIPrescNo
			if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
			set tObjToInsert.NroDocumento = tNroDocumento
			
			//Usuario
			set tUserToSendERP = ""
			set tUserToSendERP =..GetDispUserToSendERP()
			if tUserToSendERP = ""
			{
				set tUserToSendERP = pUsuario
			}
			
			set tObjToInsert.Usuario = 	pUsuario
			
			//Episodio
			set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
			//Paciente
			set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
			if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
			{
				set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
				
				Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			}
			
			
			///Datos Item
			set tCodERP = ""
			set tOEORIItmMastDR = tObjOrder.OEORIItmMastDR.%Id()
			set tCodItemMast = tObjOrder.OEORIItmMastDR.ARCIMCode
						
			//Codigo Externo
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
			}
						
			//Si no existe Homologacion se manda el codigo del item
			if tCodERP = "" set tCodERP = tCodItemMast
			set tObjToInsert.CodigoERP = tCodERP
										
			set tObjToInsert.Lote = ""
			set tObjToInsert.FecVencimiento = ""
						
			set tObjToInsert.CantIntentos = 0
			set tObjToInsert.EstadoEnvio = "Ingresado"
			set tObjToInsert.ProcIngreso = "ReturnOmnicellSuppliesToERP-Int Omn"
				
			set tSC = tObjToInsert.%Save()	
						
			do ##class(Custom.ERP.StockHandler).UpdateManualStock(tObjOrder.OEORIRecDepDR.%Id(),tObjOrder.OEORIItmMastDR.ARCIMCode,pQty,"-","","")
								
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
	
		if tUserToSendERP = "" set tUserToSendERP = pUsuario
		set tResp = ..EnvioDispToERP("Grupo", "", tgroupId, tUserToSendERP)
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
	}
		
	Quit tSC
	
	/* Codigo Anterior
	
	set Resp="1"
	Set tSC = $$$OK
	set ^zjb("ReturnSup",1)="1 "_OrderIds
	
	set tOK = 1
	set tLastLocal = ""
	set tCurrentLocal = "" 
	Try
	{
		if OrderIds = "" Quit
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
			
		
			
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set tUserCode = ""
		if pUserId '= ""
		{
			&sql(select SSUSR_Initials
				into :tUserCode
				from SQLUser.SS_User
				where %id = :pUserId 
				)
			if SQLCODE '= "" set tUserCode = ""
		}
		
		if tUserCode = "" set tUserCode = "Omn"
		set InsCount = 1
		
		while (tId '="") && (tOK = 1)
		{	
			set ^zjb("ReturnSup",1,itm)="1 "_tId
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			
			if '$IsObject(tObjOrder) set Resp = "Item ya no existe en la base de Datos", tOK = 0 
			
			set tItemDescription = ""
			set tItemDescription = tObjOrder.OEORIItmMastDR.ARCIMDesc
			
			set tCurrentLocal = tObjOrder.OEORIRecDepDR.%Id()
			
			set tNroOrdenERP = ""
			set tNroOrdenERP = tObjOrder.OEORIPrescNo
			if tNroOrdenERP ="" set tNroOrdenERP = tObjOrder.OEORIBBExtCode
			set ^zjb("ItemIns",2)="2 "_tObjOrder
			set tAdmId = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.%Id()
			//set ^zjb("ItemIns",3)="3 "_'$IsObject(tObjOrder)
			if '$IsObject(tObjOrder) Quit
			//Se Construye una sola vez el Encabezado
			
			//Check si la subcategoria corresponde a Insumos a ERP
			set tSubcategoryCode = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICCommissioning
			set tSubcategoriaType = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrderType
			
			if InsCount = 1 
			{	
				
				set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
				set tObjSend.User = tUserCode
				set tObjSend.FacilityCode = 1000
				set tObjSend.DocumentNo = tNroOrdenERP
				set tObjSend.MovementCode = "S003"
					
				
				
				set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
			
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}		
					
				Set tObjSend.PatientName = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
				Set tObjSend.Episode = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				Set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCPagerNo
				Set tObjSend.CostCenter = tObjOrder.OEORIRecDepDR.CTLOCGLCCCDR.GLCCCCode
				if tObjSend.LocationCode = "" set tObjSend.LocationCode = tObjOrder.OEORIRecDepDR.CTLOCCode
					
					
			}
				
			set InsCount =  InsCount + 1
			set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
			set tItemMasterId = tObjOrder.OEORIItmMastDR.%Id() 
			set tItemMasterCode = tObjOrder.OEORIItmMastDR.ARCIMCode 
			set ^zjb("ItemIns",6)="6 tItemMasterCode "_tItemMasterCode
			
			set tCodItemERP = ""
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodItemERP = ..GetItemExtCodeByLoc(tItemMasterId,tERPLocationId)
			}
			set ^zjb("ItemIns",7)="7 tCodItemERP "_tCodItemERP
			if tCodItemERP = "" set tCodItemERP = tItemMasterCode
			//set ^zjb("ItemIns",8)="8 tCodItemERP "_tCodItemERP
				
			set tObjSendItem.StockItemCode = tCodItemERP
			
			set tObjSendItem.Quantity =  pQty
			set tObjSendItem.SerialNumber = tObjOrder.%Id()
			
			
			do ##class(Custom.ERP.StockHandler).UpdateManualStock(tObjOrder.OEORIRecDepDR.%Id(),tObjOrder.OEORIItmMastDR.ARCIMCode,pQty,"+","","")
				
			do tObjSend.Items.Insert(tObjSendItem)
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
			
		}
			
		
	
		
		if tOK = 0 Quit
		//Salir si no está activa la integracion
		if 'tIntegrationOn Quit
		
		
		//set ^zjb("ItemIns",11)="11 "_tObjSend.Items.Count()
		if tObjSend.Items.Count() > 0 
		{
			// Enviar Mensaje
			Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
			Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
			set tWSSend.Timeout = 300
			
			//Traer la localización de WS según parametros
			Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
			If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
			//set ^zjb("ItemIns",12)="12 "_tSC
			Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
			//set ^zjb("ItemIns",13)="13 "_tSC
			Quit:$System.Status.IsError(tSC)
		
			Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
			//set ^zjb("ItemIns",14)="14 "_tSC
			Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
			//set ^zjb("ItemIns",15)="15 "_tSC
			if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcion = pResponse.ERPResponse.ErrorDescription
			//If $System.Status.IsError(tSC) Quit
			
			if pResponse.ERPResponse.IsError
			{
				set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
				//Generar Traza para asociar al item de orden en caso de error y volver a enviar
				for i=1:1:tObjSend.Items.Count()
				{	
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						set tTextError = ""
						if pResponse.ERPResponse.IsError '= "" set tTextError = pResponse.ERPResponse.ErrorDescription
					
						set Resp = "Error al Integrar con ERP: "_tTextError
						set tTextToResend = ""
						 //1 Tipo Mov;2 NroReceta/Doctp;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 ,10 Fecha ($h); 11 Hora($h);12 Cod Usuario, 13 Error
						//S002 Consumo Directo Farmacos->MovementCode(;)DocumentNo(;)LocationCode(;)FacilityCode(;)StockItemCode(;)Quantity(;)BatchNumber(;)ExpiryDate
						set tTextToResend = tObjSend.MovementCode_"(;)"_tObjSend.DocumentNo_"(;)"_tObjSend.LocationCode_"(;)"_tObjSend.FacilityCode_"(;)"_tObjSend.Items.GetAt(i).StockItemCode_"(;)"_tObjSend.Items.GetAt(i).Quantity
						if tObjSend.Items.GetAt(i).BatchNumber'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).BatchNumber} else {set tTextToResend = tTextToResend_"(;)"}
						if tObjSend.Items.GetAt(i).ExpiryDate'="" {set tTextToResend = tTextToResend_"(;)"_tObjSend.Items.GetAt(i).ExpiryDate} else {set tTextToResend = tTextToResend_"(;)"}
						set tTextToResend = tTextToResend_"(;)"_$p($h,",",1)_"(;)"_$p($h,",",2)_"(;)"_tUserCode_"(;)"_$extract(tTextError,1,55)
						
						//Actualiza estado de Integración
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tTextToResend,"ERR","ERP",tTextError)
						
					
					}			
				}
					
			}
			else
			{
				set ^zjb("NoError",1)="1 "_tObjSend.DocumentNo
				for i=1:1:tObjSend.Items.Count()
				{
					set tOrderId = ""
					set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
					if tOrderId '= ""
					{
						 set tUserIdTrak = tUserCode
						
						
						
						set tDescripcion = tObjSend.DocumentNo_";"_tUserCode_";"_$p($h,",",1)_";"_$p($h,",",2)
						
						set tRespUpdate = ..UpdateTextResponse(tOrderId,tDescripcion,"E","ERP","")
						
						&sql(Update %nolock %notrigger Custom_HMIL_Test.EpisodiosItemsToFix
							set text4 = 'OK'
							where IdItem = :tOrderId)
						
	
					}			
				}	
				
			}
			
		}
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
	set ^zjb("ItemIns",18)="18 tSC "_tSC
	Quit Resp
	
	*/
}

ClassMethod GetMessageErrorFromIntegrations(tId) As %String
{
	
	
	set tObjId = "" , tText3 = "",  tText4 = "", tFinalText = ""
	
	if tId '= "" set tObjId = ##class(User.OEOrdItem).%OpenId(tId)
	if tId '= "" set tObjId2 = ##class(User.OEOrdItem2).%OpenId(tId)
	
	
	if $isObject(tObjId)
	{
		
		set tPhyQty = ""
		set tPhyQty = tObjId.OEORIPhQtyOrd
		
		set tFinalTextERP = ""
		set tFinalTextDIS = ""
		set tERPText4=""
		set tERPText3=""
		
		set tDISText4=""
		set tDISText3=""
		
		set tNroDoc = ""
		set tNroDoc = tObjId.OEORIPrescNo
		if tNroDoc = ""
		{
			set tNroDoc = tObjId.OEORILabEpisodeNo
		}
		
		if tNroDoc = ""
		{
			set tNroDoc = tObjId.OEORIBBExtCode
		}
		
		set tText4 = tObjId.OEORIText4
		set tText3 = tObjId.OEORIText3
		
		set tERPText4=$piece(tText4,"-DIS-",1)
		set tDISText4=$piece(tText4,"-DIS-",2)
		
		set tERPText3=$piece(tText3,"-DIS-",1)
		set tDISText3=$piece(tText3,"-DIS-",2)
		
		
		if tERPText4 = ""
		{
			set tFinalTextERP = "ERP: No Enviado"
		}
		elseif tERPText4 = "E" 
		{
			
			if tERPText3 '= "" 
			{
				set tUser = $p(tERPText3,";",2), tDate = $p(tERPText3,";",3), tTime = $p(tERPText3,";",4)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				if tNroDoc '= ""
				{
					set tFinalTextERP = "Enviado a ERP: "_tUser_" Fecha: "_tDate_" "_tTime
				}
				else
				{
					set tFinalTextERP = "Enviado a ERP: "_tUser_" Fecha: "_tDate_" "_tTime
				}
			}
			
			
		}
		elseif tERPText4 = "ERR" 
		{
			if tERPText3 '= "" 
			{
				 //1 Tipo Mov;2 NroReceta/Docto;3 Local;4 Hospital;5 ItemHomologado;6 Cantidad;7 Lote;8 Fecha;9 Fecha ($h); 10 Hora($h);11 Cod Usuario, 12 Error
				
				set tUser = $p(tERPText3,"(;)",11), tDate = $p(tERPText3,"(;)",9), tTime = $p(tERPText3,"(;)",10)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tError = $p(tERPText3,"(;)",12)
				set tTipoMov = $p(tERPText3,"(;)",1)
				set tTipoDesc =""
				if tTipoMov = "S002" set tTipoDesc = "Dispensación"
				if tTipoMov = "S003" set tTipoDesc = "Devolución"
				if tTipoMov = "S004" set tTipoDesc = "Merma" 
				if tTipoDesc = ""
				{				
					set tFinalTextERP = "Error ERP Integracion. Usuario: "_tUser_" Fecha: "_tDate_" "_tTime_". Det: "_tError
				}
				else
				{
					set tFinalTextERP = "Error ERP Tipo: "_tTipoDesc_". Usuario "_tUser_" Fecha: "_tDate_" "_tTime_". Det: "_tError
				}
			}
			
			
		}
		elseif tERPText4 = "D" 
		{
	
			if tERPText3 '= "" 
			{
				set tUser = $p(tERPText3,";",2), tDate = $p(tERPText3,";",3), tTime = $p(tERPText3,";",4)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tFinalTextERP = "Despachado por Usuario: "_tUser_" Cant. Solicitado "_$p(tERPText3,";",5)_" Despachado "_$p(tERPText3,";",6)_" Fecha: "_tDate_" "_tTime
			}
			
			
		}
	
	/////Dispensadores
	
		set tDispensado = 0
		set tMayorDisp= 0
		
		if tDISText4 = ""
		{
			set tFinalTextDIS = "Kardex/Omnicell: No Enviado"
		}
		elseif tDISText4 = "E" 
		{
			
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",2), tTime = $p(tDISText3,";",3)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				if tNroDoc '= ""
				{
					set tFinalTextDIS = "Enviado a Kardex/Omnicell: "_tUser_" Fecha: "_tDate_" "_tTime
				}
				else
				{
					set tFinalTextDIS = "Enviado a  Kardex/Omnicell "_tUser_" Fecha: "_tDate_" "_tTime
				}
			}
			
			
		}
		elseif tDISText4 = "ER" 
		{
			set tDISText3 = tObjId.OEORIText3
			if tDISText3 '= "" 
			{
				set tError = $p(tDISText3,"[",1)
								
				set tFinalTextDIS = "Error DIS Integracion: "_tError
			}
			
			
		}
		elseif tDISText4 = "D"
		{
	
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",4), tTime = $p(tDISText3,";",5)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tDetalle = " Total: "_$p(tDISText3,";",2)_" Dispensado "_$p(tDISText3,";",3)
				set tDispensado = $p(tDISText3,";",7)
				set tMayorDisp = ""
				set tMayorDisp = $p(tDISText3,";",6)
				
				set tFinalTextDIS = "Dispensado por Usuario: "_tUser_tDetalle_" Fecha: "_tDate_" "_tTime
				
				if tMayorDisp '= "" set tFinalTextDIS = "Dispensado por Usuario: "_tUser_tDetalle_" Fecha: "_tDate_" "_tTime_" ERR: Se ha dispensado "_tMayorDisp_" unidades más que lo solicitado"
			}
			
			
		}
		elseif tDISText4 = "DP"
		{	set ^zjb("Disp",tId,2)= "2 "_tDISText4_" tDISText3 "_tDISText3
	
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",4), tTime = $p(tDISText3,";",5)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tDetalle = " Total: "_$p(tDISText3,";",2)_" Dispensado "_$p(tDISText3,";",3)
				set tDispensado = $p(tDISText3,";",7)
				set tFinalTextDIS = "Dispensado por Usuario: "_tUser_tDetalle_" Fecha: "_tDate_" "_tTime
			}
			
			
		}
		elseif tDISText4 = "NS"
		{	//set ^zjb("Disp",tId,2)= "2 "_tDISText4_" tDISText3 "_tDISText3
	
			if tDISText3 '= "" 
			{
				set tUser = $p(tDISText3,";",1), tDate = $p(tDISText3,";",4), tTime = $p(tDISText3,";",5)
				if tDate '= "" set tDate = $zd(tDate,4)
				if tTime '= "" set tTime = $zt(tTime,1)
				
				set tDetalle = " No hay sufuciente Stock Disponible en Bodega. Requerido: "_$p(tDISText3,";",2)_" Disponible: "_$p(tDISText3,";",3)
				
				set tFinalTextDIS = "Error DIS Integracion: "_tDetalle_" Fecha: "_tDate_" "_tTime
			}
			
			
		}
	}
	
	quit tFinalTextERP_"^"_tFinalTextDIS_"^"_tDispensado_"^"_tMayorDisp
}

ClassMethod DevolucionIsOk(pOrders As %String) As %String
{
	Set tSC = $$$OK
	Set tResp = 0
	//set ^zjb("isDev",1)="1 pOrders "_pOrders
	
	Try
	{
		if pOrders = "" Quit
		
		set conta = 1
		set isOk = 0
		set tOrderId = $piece(pOrders,"^",conta)
		
		
		while (tOrderId '= "") && (isOk=0)
		{
			
			set tPharmacyStat = ""
			set tPharmacyStat = $$pharmst^COEOrdItem6(tOrderId)
			
			if $get(tPharmacyStat) = "J"
			{
				set isOk = 1
				//set tResp = 1
				set ^DevolucionIsOkTmp(%session.SessionId,tOrderId)=1
			}
			
			set conta = conta + 1
			set tOrderId = $piece(pOrders,",",conta)
		
		}
		
		if $data(^DevolucionIsOkTmp(%session.SessionId))
		{
			set tCurrentId = ""
			set tCurrentId = $order(^DevolucionIsOkTmp(%session.SessionId,tCurrentId))
			
			while tCurrentId '= ""
			{
				if tResp = 0
				{
					set tResp = tCurrentId
				}
				else
				{
					set tResp=tResp_","_tCurrentId
				}
				
				set tCurrentId = $order(^DevolucionIsOkTmp(%session.SessionId,tCurrentId))
			}
		}
		
		kill ^DevolucionIsOkTmp(%session.SessionId)
	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		Set tResp = ""
		
		
	}
	//set ^zjb("isDev",2)="2 tSC "_tSC
	//set ^zjb("isDev",3)="3 tResp "_tResp
	
	Quit tResp
}

ClassMethod UpdateManualStock(pLocalId As %String, pItemCode As %String, pQty As %String, pSign As %String, pBatch As %String, pExpDate As %String) As %String
{
	Set tSC = $System.Status.OK()
	Try 
	{	
		set tObjStock = ##class(Custom.ERP.WS.s0.StockItems).%New()
		set tObjStock.StockItemCode = pItemCode
		set tObjStock.Quantity = pQty
		set tObjStock.BatchNumber = pBatch
		set tObjStock.ExpiryDate = pExpDate
		
		
		set tSC = ##class(Custom.Nexus.WSEventHandler.StockHandler).StockManualUpdate(pLocalId, tObjStock, "", pSign)
		
		
		
	} Catch (tException)
	{
		Set tSC = tException.AsStatus()
		//set ^zjb("UpdateManualStock",3)="3 "_tSC 
		
		
	}
	//set ^zjb("UpdateManualStock",4)="4 "_tSC 
	Quit "1"
}

ClassMethod DeleteIngredient(pId As %String) As %String
{
	set tResponse = "1"
	
	if pId = "" Quit "Debe Seleccionar un Ingrediente a Elimminar"
	
	&sql(delete %nolock %notrigger from SQLUser.INC_ItmRecIngr
		 where %id = :pId )
	
	if SQLCODE '= 0 set tResponse = "Ha ocurrido un error al Intentar Eliminar"
		
	quit tResponse
}

ClassMethod GetDispUserToSendERP() As %String
{
	if $data(^DispensadorUserHosmilToERP)
	{
		if ^DispensadorUserHosmilToERP = 10
		{
			set ^DispensadorUserHosmilToERP = 1
		}
		else
		{
			set ^DispensadorUserHosmilToERP = ^DispensadorUserHosmilToERP + 1
		}
	}
	else
	{
		set ^DispensadorUserHosmilToERP = 1
	}
	
	return "IntDisp"_^DispensadorUserHosmilToERP
}

ClassMethod FiltraDevoluciones(pRS) As %Integer
{
	
	//set ^zjb("filtroDev",1)="1"
	
	set tId = ""
	set tId = pRS.Data("ID")
	
	
	if tId '= ""
	{
	
		set tEstadoFarmacia = ""
		set tEstadoFarmacia = $$pharmst^COEOrdItem6(tId)
		
		if ($get(tEstadoFarmacia) '= "") 
		{
		
			if '($get(tEstadoFarmacia) [ "J" )
			{
				quit 0
			}
		}
	
	}
	
	
	
	//set pRS.Data("PAPMIName4") = tPago
	
	quit 1
}

ClassMethod IsOkToExecutedOrderLogistica(pOrders As %String) As %String
{
	//set ^zjb("isDev",0)="1 pOrders "_pOrders
	
	Try
	{
		set tResp = 1
		set ItemStatus = ""
		set ItemStatus = $g(%request.Data("newOEItemStatus",1))
		//set ^zjb("isDev","01")="01 ItemStatus "_ItemStatus
		if ItemStatus = "E"
		{
			
			set orditm = 1
			while (($piece(pOrders,"^",orditm)) '= "") && (tResp = 1)
			{
				set ordid = ""
				set ordid=$piece($get(^TMP("WEB","ORDER_ENTRY","OEORI_ROWID",%session.SessionId,"ChangeStatus",orditm)),"*",1)
				
				if $get(ordid) '= ""
				{
					//set ^zjb("isDev",ordid,1) = ordid
					set tObjOrder = ##class(User.OEOrdItem).%OpenId(ordid)
				
					if $IsObject(tObjOrder)
					{
						//set ^zjb("isDev",ordid,2) = ordid
						set tSubcatType = ""
						if $IsObject(tObjOrder.OEORIItmMastDR.ARCIMItemCatDR)
						{
							set tSubcatType = ""
							set tSubcatType = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrderType
							
							if ($get(tSubcatType) = "SUP") || (($get(tSubcatType) = "R")) ||($get(tSubcatType) = "I" )
							{
								//set ^zjb("isDev",ordid,3) = ordid
								set tResp = 0
							}
							
						}
						
					}
				}
			
			
				set orditm =  orditm +1
			}
		
		}	
	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		Set tResp = "1"
		
		
	}
	
	
	Quit tResp
}

ClassMethod SendEstadiasCeroOmnicell(pFechaDesde, pFechaHasta, pLocal, pFicha, pEpisodio) As %String
{
	
	//set ^zjb("sendEstadias",1)="1 pFechaDesde "_pFechaDesde_" pFechaHasta "_pFechaHasta_" pLocal "_pLocal_" pFicha "_pFicha_" pEpisodio "_pEpisodio
	set tResp = 0
	set tConta = 0

	Try
	{
		if pFicha = "" set tResp = "El numero de Ficha es Obligatorio" quit
		if pFechaDesde = "" set tResp = "La Fecha Desde es Obligatoria" quit
		if pFechaHasta = "" set tResp = "La Fecha Hasta es Obligatoria" quit
		if pLocal = "" set tResp = "El Local es Obligatorio" quit
		if pEpisodio = "" set tResp = "El Número de Episodio es Obligatorio" quit
		
		set tTypeEpisode = $extract(pEpisodio,1,1)
		
		set (tPatientIdAdm,tPatientIdFicha,tEpisodeId) = ""
		set tEpisodeId = $order(^PAADMi("No",pEpisodio,""))
		if tEpisodeId '= ""
		{
			 set tPatientIdAdm = $piece(^PAADM(tEpisodeId),"^",1)
			 
			 if $get(pFicha)'= ""
 			 {
 				set tFicha = $order(^RT(0,"MRNo",pFicha,""),-1)
 	
 				if $get(tFicha) '= ""
 				{
	 				set tPatientIdFicha = $piece(^RT(tFicha),"^",2)
	 	
 				}
 			 }
		}
		
		//set ^zjb("sendEstadias",2)=" tPatientIdAdm "_tPatientIdAdm_" tPatientIdFicha "_tPatientIdFicha
		if (tPatientIdAdm="") || (tPatientIdFicha="") || (tPatientIdAdm'=tPatientIdFicha)
		{
			set tResp = "El Número de Ficha no Corresponde con el Episodio" quit
		}
		
		set tLocalTrak = ""
		if $get(pLocal)'=""
		{
			&sql(SELECT %id
				into :tLocalTrak
			 	FROM SQLUser.CT_Loc
			 	WHERE CTLOC_Desc = :pLocal
			 	)
			if SQLCODE '= 0 set tLocalTrak = ""
		}
		
		//set ^zjb("sendEstadias",3)=" tLocalTrak "_tLocalTrak
		if tLocalTrak = "" set tResp = "No se ha encontrado el Local Asociado a: "_pLocal quit
		
		//set ^zjb("sendEstadias",4)=" tLocalTrak "_tLocalTrak
		
		
		&sql(declare C1 CURSOR FOR
			select bodega,cantidadProcesada,cantidadSolicitada,codArticulo,errorDescription,fecha,fechaOriginal,hora,horaOriginal,idRegistro,localTrak,nombrePaciente,numeroEstadia,numeroFicha,numeroPrescripcion,procesado,tipoAtencion,tipoDisplay,tipoError,usuario
			into   :tbodega,:tcantidadProcesada,:tcantidadSolicitada,:tcodArticulo,:terrorDescription,:tfecha,:tfechaOriginal,:thora,:thoraOriginal,:tidRegistro,:tlocalTrak,:tnombrePaciente,:tnumeroEstadia,:tnumeroFicha,:tnumeroPrescripcion,:tprocesado,:ttipoAtencion,:ttipoDisplay,:ttipoError,:tusuario
			from Custom_HMIL_User.OmnicellErrores
			where fechaOriginal >=to_date(:pFechaDesde,'dd/mm/yyyy')
  			  and fechaOriginal <=to_date(:pFechaHasta,'dd/mm/yyyy')
  			  and localTrak = :tLocalTrak
  			  and numeroFicha = :pFicha
  			  and numeroEstadia = 0
  			  and tipoAtencion = :tTypeEpisode
  			  and procesado = 'N'
 			)
		
		&sql(OPEN C1)
 		&sql(FETCH C1)
     	while (SQLCODE=0) 
        {
	        set tUserReturn = ""
	        set tUserReturn = $g(%session.Data("LOGON.USERCODE"))
	        if $get(tUserReturn)="" set tUserReturn = "TrakDefault"
	        set tDescriptionReturn = "Act Est 0;User:"_tUserReturn_";Fecha:"_$h
	        
	        //set ^zjb("sendEstadias",5) = "5 "_tDescriptionReturn
	        
	        Set tReturn = ##class(OmnicellWS.s0.Diferencia1).%New()
			set tReturn.MessageType = "A"
			Set tReturn.idRegistro = tidRegistro
			Set tReturn.numeroEstadia = pEpisodio
			Set tReturn.tipoError = "UptEstadia"
			Set tReturn.ErrorDescription = $extract(tDescriptionReturn,1,50)
	        
	        
	        Set tService = ##class(OmnicellWS.WSServiceSoap).%New()
			Set res = tService.Diferencia(tReturn)
			
			set tConta = tConta+1
			
			&sql(Update %nolock %notrigger Custom_HMIL_User.OmnicellErrores
				set numeroEstadia = 1
				where idRegistro = :tidRegistro
				)
			
		
	        &sql(FETCH C1)
        }
		&sql(CLOSE C1)
		
	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		Set tResp = "Ha ocurrido un error en el proceso, contactese con Informática. Detalle: "_tSC
		
		
	}
	
	
	if (tResp = 0)
	{
		if tConta = 0
		{
			set tResp = "No hay Items para procesar para el Episodio "_pEpisodio_", Revise si el Tipo de Episodio Corresponde"
		}
		else
		{
			set tResp = "Se han procesado "_tConta_" Items"
		}
	}
	Quit tResp
}

ClassMethod SendTransfersToKardex(pDesde, pLocKardex, pLocalDespacha, pNumero) As %String
{
	
	//set ^zjb("SendTransferToKardex",1)="1 pDesde "_pDesde_" pLocKardex "_pLocKardex_" pLocalDespacha "_pLocalDespacha_" pNumero "_pNumero
	set tResp = 0
	set tConta = 0

	Try
	{
		set (tLocKardexCode, tlocalDespachaCode)=""
		
		&sql(select CTLOC_Code
			into :tLocKardexCode
			from SQLUser.CT_Loc
			where CTLOC_desc = :pLocKardex
			)
			
			if SQLCODE '= 0 set tLocKardexCode = ""
		
		&sql(select CTLOC_Code
			into :tlocalDespachaCode
			from SQLUser.CT_Loc
			where CTLOC_desc = :pLocalDespacha
			)
			
			if SQLCODE '= 0 set tlocalDespachaCode = ""
		
		if (tLocKardexCode = "") || (tlocalDespachaCode = "")
		{
			set tResp = "No se encuentra definda la bodega"
			quit
		}
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.TranspasosKardex")
		//Salir si no está activa la integracion
		if 'tIntegrationOn 
		{
			set tResp = "Integracion Inactiva"
			Quit	
		}
		
		Set tWSSend = ##class(Custom.ERP.GetTransferKardex.GetTransferFromERPSoap).%New()
		
		//Traer la localización de WS según parametros
		Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.TranspasosKardex")
		If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
		
		
		set tObjSend = ##class(Custom.ERP.GetTransferKardex.s0.StockRequest).%New()
		set tObjSend.DocumentNo = pNumero
		set tObjSend.FromLocationCode = tlocalDespachaCode
		set tObjSend.ToLocationCode = tLocKardexCode
		set tObjSend.Description = pDesde
		set tObjSend.UserName = $g(%session.Data("LOGON.USERCODE"))
		
		Set pResponse = ##class(Custom.ERP.GetTransferKardex.s0.Response).%New()
		Set RespWS = tWSSend.GetTransferToKardex(tObjSend,.pResponse)
		
		//set ^zjb("SendTransferToKardex",2)= " RespWS "_RespWS_" pResponse "_pResponse.IsError_" pResponseDesc "_pResponse.ErrorDescription
		
		set tResp = pResponse.ErrorDescription
		
		
		
	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		//set ^zjb("SendTransferToKardex",3)= tSC
		Set tResp = "Ha ocurrido un error en el proceso, contactese con Informática"
		
		
	}
	
	
	
	Quit tResp
}

ClassMethod ManualSendToLisRis(OrderIds) As %String
{
	Set tSC = $$$OK
	Set tResp = "1"
	//set ^zjb("ItemInsReenv",0)="0 "_OrderIds
	
	
	Try
	{
		if OrderIds = "" 
		{
			set tResp = "Debe elegir al menos un Item"
			Quit
		}
		
		set ind = 1
		set tId = $piece(OrderIds,"^",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		while (tId '="") && (tResp = "1")
		{	
			//set ^zjb("ItemInsReenv",1,tId)="1 "_tId
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue	
			}
			
			set (tText4,tEpisodeType) = ""
			set tText4 = tObjOrder.OEORIText4
			set tOrdenDesc = tObjOrder.OEORIItmMastDR.ARCIMDesc
			set tEpisodeType=tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMType
			
			
			//if $get(tText4) = "P" 
			//{
			//	set tResp = "El Item "_tOrdenDesc_" ya fue enviado"
			//}
			
			//if $get(tEpisodeType) '= "O" 
			//{
			//	set tResp = "El Item "_tOrdenDesc_" NO es ambulatorio"
			//}
						
			set ind = ind+1
			set tId = $piece(OrderIds,"^",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
		
		
		set ind = 1
		set tId = $piece(OrderIds,"^",ind)
		
		//set ^zjb("ItemInsReenv",0,tId)="0 "_tId_" tResp "_tResp
		
		while (tId '="") && (tResp = "1")
		{	
			//set ^zjb("ItemInsReenv",2,tId)="1 "_tId
			
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				continue	
			}
			
			set tText4 = ""
			set tText4 = tObjOrder.OEORIText4
			set tOrdenDesc = tObjOrder.OEORIItmMastDR.ARCIMDesc
			
			
			//if $get(tText4) = "P" 
			//{
			//	set tResp = "El Item "_tOrdenDesc_" ya fue enviado"
			//}
		
			//set ^zjb("ItemInsReenv",3,tId)="1 "_tId
			
			do ##class(Custom.Nexus.Facade.BillingERP).SendOrdItemPaid(tId)
			
			if $System.Status.IsError(tSC)
			{
				set tResp = tSC
				quit
			}
			
						
			set ind = ind+1
			set tId = $piece(OrderIds,"^",ind)
			
		}
		
		
		
		
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		Set tResp = tSC
		//set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
	//set ^zjb("ItemIns",18)="18 tSC "_tSC_" tResp "_tResp
	Quit tResp
}

ClassMethod EnvioDispToERP(pType As %String = "Ind", OrderId As %String = "", OrderGroup As %String = "", pUser As %String = "") As %String
{
	Set tSC = $$$OK
	set tResp = tSC
	Try
	{
		////set ^zjb("NuevoEnvio",0)="pType "_pType_" OrderId "_OrderId_" OrderGroup "_OrderGroup_" pUser "_pUser
		If (pType = "Ind") && (OrderId = "")
		{
			quit
		}
		
		If (pType = "Grupo") && (OrderGroup = "")
		{
			quit
		}
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		
		if pType = "Grupo"
		{
			//set ^zjb("NuevoEnvio",1)="OrderGroup "_OrderGroup
			&sql(declare EnvioGrupoERP Cursor for
				 select distinct localCodeERP, NroDocumento,TipoMovimiento,Episodio, DetallePaciente, Ubicacion, CentroCosto
				 into :tLocalERP, :tNroDocumento, :tTipoMovimiento,:tEpisodio, :tDetallePaciente,:tUbicacion,:tCentroCosto
				 from Custom_User.DispensacionesERP
				 where OrderGroupId = :OrderGroup
				   and (EstadoEnvio = 'Ingresado' or EstadoEnvio = 'Error')
				   and Cantidad > 0
				   and NroTransERP is null		   
				   and  (DetalleError not like  '%Movimiento ya registrado en SAP%'or DetalleError is null)
				   )
				 
				 
				
				 
			&sql(open EnvioGrupoERP)
			&sql(fetch EnvioGrupoERP)
			
			while SQLCODE = 0
			{
				set ind = 0
				if tIntegrationOn
				{
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					set tObjSend.User = pUser
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroDocumento
					set tObjSend.MovementCode = tTipoMovimiento
					Set tObjSend.PatientName = tDetallePaciente
					Set tObjSend.Episode = tEpisodio
					Set tObjSend.LocationCode = tLocalERP
					Set tObjSend.CostCenter = tCentroCosto
					Set tObjSend.PatientLocation = tUbicacion
					
				}
				
				
				&sql(declare EnvioDetalleGrupoERP Cursor for
				 	 select %id, Lote , FecVencimiento, Cantidad, CodigoERP,OrderRef->OEORI_ProsBatchNo,OrderRef->OEORI_ProsSerialNo,OrderRef->OEORI_ExpiryDate
				 	 into  :tid,:tLote,:tFecVencimiento, :tCantidad, :tCodigoERP,:tLote2, :tSerie2, :tFechaExp2 
				 	 from Custom_User.DispensacionesERP
				 	 where OrderGroupId = :OrderGroup
				       and TipoMovimiento = :tTipoMovimiento
				       and (EstadoEnvio = 'Ingresado' or EstadoEnvio = 'Error')
				       and localCodeERP = :tLocalERP
				       and NroDocumento = :tNroDocumento
				       and Cantidad > 0
				     )
				
				&sql(open EnvioDetalleGrupoERP)
				&sql(fetch EnvioDetalleGrupoERP)
				while SQLCODE = 0
				{
					//set ^zjb("NuevoEnvio",2,tid)="tid "_tid
					
					if tIntegrationOn
					{
						set ind = ind+1
						///Item
						set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
						set tObjSendItem.StockItemCode = tCodigoERP	
						set tObjSendItem.Quantity = tCantidad
						if tFecVencimiento = ""
						{
							if $get(tFechaExp2)'="" set tObjSendItem.ExpiryDate = tFechaExp2
						}
						else
						{
							set tObjSendItem.ExpiryDate = tFecVencimiento
						}
						
						if tLote = ""
						{
							if $get(tLote2)'="" set tObjSendItem.BatchNumber = tLote2
						}
						else
						{
							set tObjSendItem.BatchNumber = tLote
						}
						
						if $get(tSerie2) '= "" 
						{
							set tObjSendItem.MedicalProgram = tSerie2
						} 
						set tObjSendItem.SerialNumber = tid
				
						do tObjSend.Items.Insert(tObjSendItem)
						
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Activa',
							     EstadoEnvio = 'Enviado',
							     PosicionEnvio = :ind,
							     DetalleError = null							     
							 where %id = :tid)
						
					}
					else
					{
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Inactiva'
							 where %id = :tid)	
					}
					
					
					&sql(fetch EnvioDetalleGrupoERP)
				}
				&sql(close EnvioDetalleGrupoERP)
				
				
				///Envio mensaje
				if tIntegrationOn
				{
					if tObjSend.Items.Count() > 0 
					{
						// Enviar Mensaje
						Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
						Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
						set tWSSend.Timeout = 30
			
						//Traer la localización de WS según parametros
						Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
						If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
						//set ^zjb("ItemIns",12)="12 "_tSC
						Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
						//set ^zjb("ItemIns",13)="13 "_tSC
						Quit:$System.Status.IsError(tSC)
		
						Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
						//set ^zjb("ItemIns",14)="14 "_tSC
						Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
						//set ^zjb("ItemIns",15)="15 "_tSC
						set tDescripcionError = ""
						if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcionError = pResponse.ERPResponse.ErrorDescription
						//If $System.Status.IsError(tSC) Quit
			
						if pResponse.ERPResponse.IsError
						{
							set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
							//Generar Traza para asociar al item de orden en caso de error y volver a enviar
							for i=1:1:tObjSend.Items.Count()
							{	
								set tOrderId = ""
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Error',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     DetalleError = :tDescripcionError
							 			 where %id = :tOrderId
							 			   and EstadoEnvio<>'Procesado en ERP'
										   and EstadoEnvio<>'Error')
									
								}
							
							}			
						}
						else	
						{
							
							for i=1:1:tObjSend.Items.Count()
							{
								set (tOrderId,tNroERP) = ""
								if pResponse.ERPResponse.ErrorDescription '= "" set tNroERP = pResponse.ERPResponse.ErrorDescription
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Procesado en ERP',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     NroTransERP = :tNroERP,
							     		     DetalleError = null
							 			 where %id = :tOrderId)
								}
											
							}			
						}	
				
					}
			
				}
				
				
				&sql(fetch EnvioGrupoERP)
			}
			&sql(close EnvioGrupoERP)
			
		}
		
		
		////Individual
		if pType = "Ind"
		{
			if OrderId = ""
			{
				set tResp = "No hay Items Seleccionados"
				quit
			}
			
			set (tListId) = ""
			set tListId = $LFS(OrderId,"^")
			
			&sql(declare EnvioIndERP Cursor for
				 select distinct localCodeERP, NroDocumento,TipoMovimiento,Episodio, DetallePaciente, Ubicacion, CentroCosto
				 into :tLocalERP, :tNroDocumento, :tTipoMovimiento,:tEpisodio, :tDetallePaciente,:tUbicacion,:tCentroCosto
				 from Custom_User.DispensacionesERP
				 where OrderRef %inlist :tListId
				   and (EstadoEnvio = 'Ingresado' or EstadoEnvio = 'Error')
				   and Cantidad > 0
				   and NroTransERP is null		   
				   and  (DetalleError not like  '%Movimiento ya registrado en SAP InventoryGenExits%' or DetalleError is null)
				   )
				 
				 
				
				 
			&sql(open EnvioIndERP)
			&sql(fetch EnvioIndERP)
			
			while SQLCODE = 0
			{
				set ind = 0
				if tIntegrationOn
				{
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					set tObjSend.User = pUser
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroDocumento
					set tObjSend.MovementCode = tTipoMovimiento
					Set tObjSend.PatientName = tDetallePaciente
					Set tObjSend.Episode = tEpisodio
					Set tObjSend.LocationCode = tLocalERP
					Set tObjSend.CostCenter = tCentroCosto
					Set tObjSend.PatientLocation = tUbicacion
					
				}
				
				
				&sql(declare EnvioDetalleIndERP Cursor for
				 	 select %id, Lote , FecVencimiento, Cantidad, CodigoERP,OrderRef->OEORI_ProsBatchNo,OrderRef->OEORI_ProsSerialNo,OrderRef->OEORI_ExpiryDate
				 	 into  :tid,:tLote,:tFecVencimiento, :tCantidad, :tCodigoERP, :tLote2, :tSerie2, :tFechaExp2 
				 	 from Custom_User.DispensacionesERP
				 	 where Orderref %inlist :tListId
				       and TipoMovimiento = :tTipoMovimiento
				       and (EstadoEnvio = 'Ingresado' or EstadoEnvio = 'Error')
				       and localCodeERP = :tLocalERP
				       and NroDocumento = :tNroDocumento
				       and Cantidad > 0
				     )
				
				&sql(open EnvioDetalleIndERP)
				&sql(fetch EnvioDetalleIndERP)
				while SQLCODE = 0
				{
					if tIntegrationOn
					{
						set ind = ind +1
						///Item
						set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
						set tObjSendItem.StockItemCode = tCodigoERP
						set tObjSendItem.Quantity = tCantidad	
						if tFecVencimiento = ""
						{
							if $get(tFechaExp2)'="" set tObjSendItem.ExpiryDate = tFechaExp2
						}
						else
						{
							set tObjSendItem.ExpiryDate = tFecVencimiento
						}
						
						if tLote = ""
						{
							if $get(tLote2)'="" set tObjSendItem.BatchNumber = tLote2
						}
						else
						{
							set tObjSendItem.BatchNumber = tLote
						}
						
						if $get(tSerie2) '= "" 
						{
							set tObjSendItem.MedicalProgram = tSerie2
						} 
						
						set tObjSendItem.BatchNumber = tLote
						set tObjSendItem.SerialNumber = tid
				
						do tObjSend.Items.Insert(tObjSendItem)
						
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Activa',
							     EstadoEnvio = 'Enviado',
							     PosicionEnvio = :ind,
							     DetalleError = null
							 where %id = :tid)
						
					}
					else
					{
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Inactiva'
							 where %id = :tid)	
					}
					
					
					&sql(fetch EnvioDetalleIndERP)
				}
				&sql(close EnvioDetalleIndERP)
				
				
				///Envio mensaje
				if tIntegrationOn
				{
					if tObjSend.Items.Count() > 0 
					{
						// Enviar Mensaje
						Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
						Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
						set tWSSend.Timeout = 30
			
						//Traer la localización de WS según parametros
						Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
						If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
						//set ^zjb("ItemIns",12)="12 "_tSC
						Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
						//set ^zjb("ItemIns",13)="13 "_tSC
						Quit:$System.Status.IsError(tSC)
		
						Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
						//set ^zjb("ItemIns",14)="14 "_tSC
						Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
						//set ^zjb("ItemIns",15)="15 "_tSC
						set tDescripcionError = ""
						if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcionError = pResponse.ERPResponse.ErrorDescription
						//If $System.Status.IsError(tSC) Quit
			
						if pResponse.ERPResponse.IsError
						{
							//set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
							//Generar Traza para asociar al item de orden en caso de error y volver a enviar
							for i=1:1:tObjSend.Items.Count()
							{	
								set tOrderId = ""
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Error',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     DetalleError = :tDescripcionError
							 			 where %id = :tOrderId)
									
								}
							
							}			
						}
						else	
						{
							
							for i=1:1:tObjSend.Items.Count()
							{
								set (tOrderId,tNroERP) = ""
								if pResponse.ERPResponse.ErrorDescription '= "" set tNroERP = pResponse.ERPResponse.ErrorDescription
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Procesado en ERP',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     NroTransERP = :tNroERP,
							     		     DetalleError = null
							 			 where %id = :tOrderId)
								}
											
							}			
						}	
				
					}
			
				}
				
				
				&sql(fetch EnvioIndERP)
			}
			&sql(close EnvioIndERP)
			
		}
			
		////Forzado, Es solo para un administrativo que haya comprobado que el movimiento en SAP no se realizó
		if pType = "Forzado"
		{
			if OrderId = ""
			{
				set tResp = "No hay Items Seleccionados"
				quit
			}
			
			set (tListId) = ""
			set tListId = $LFS(OrderId,"^")
			
			&sql(declare EnvioForzadoERP Cursor for
				 select distinct localCodeERP, NroDocumento,TipoMovimiento,Episodio, DetallePaciente, Ubicacion, CentroCosto
				 into :tLocalERP, :tNroDocumento, :tTipoMovimiento,:tEpisodio, :tDetallePaciente,:tUbicacion,:tCentroCosto
				 from Custom_User.DispensacionesERP
				 where OrderRef %inlist :tListId
				   and (EstadoEnvio = 'Enviado')
				   and Cantidad > 0
				  and NroTransERP is null		   
				   and  (DetalleError not like  '%Movimiento ya registrado en SAP InventoryGenExits%' and DetalleError not like  '%Quantity falls into negative inventory%'  or DetalleError is null)
				   )
				 
				 
				
				 
			&sql(open EnvioForzadoERP)
			&sql(fetch EnvioForzadoERP)
			
			while SQLCODE = 0
			{
				set ind = 0
				if tIntegrationOn
				{
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					set tObjSend.User = pUser
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroDocumento
					set tObjSend.MovementCode = tTipoMovimiento
					Set tObjSend.PatientName = tDetallePaciente
					Set tObjSend.Episode = tEpisodio
					Set tObjSend.LocationCode = tLocalERP
					Set tObjSend.CostCenter = tCentroCosto
					Set tObjSend.PatientLocation = tUbicacion
					
				}
				
				
				&sql(declare EnvioDetalleForzadoERP Cursor for
				 	 select %id, Lote , FecVencimiento, Cantidad, CodigoERP
				 	 into  :tid,:tLote,:tFecVencimiento, :tCantidad, :tCodigoERP
				 	 from Custom_User.DispensacionesERP
				 	 where Orderref %inlist :tListId
				       and TipoMovimiento = :tTipoMovimiento
				       and (EstadoEnvio = 'Enviado')
				       and localCodeERP = :tLocalERP
				       and NroDocumento = :tNroDocumento
				       and Cantidad > 0
				       
				     )
				
				&sql(open EnvioDetalleForzadoERP)
				&sql(fetch EnvioDetalleForzadoERP)
				while SQLCODE = 0
				{
					if tIntegrationOn
					{
						set ind = ind +1
						///Item
						set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
						set tObjSendItem.StockItemCode = tCodigoERP	
						set tObjSendItem.Quantity = tCantidad
						set tObjSendItem.ExpiryDate = tFecVencimiento
						set tObjSendItem.BatchNumber = tLote
						set tObjSendItem.SerialNumber = tid
				
						do tObjSend.Items.Insert(tObjSendItem)
						
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Activa',
							     EstadoEnvio = 'Enviado',
							     PosicionEnvio = :ind,
							     DetalleError = null
							 where %id = :tid)
						
					}
					else
					{
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Inactiva'
							 where %id = :tid)	
					}
					
					
					&sql(fetch EnvioDetalleForzadoERP)
				}
				&sql(close EnvioDetalleForzadoERP)
				
				
				///Envio mensaje
				if tIntegrationOn
				{
					if tObjSend.Items.Count() > 0 
					{
						// Enviar Mensaje
						Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
						Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
						set tWSSend.Timeout = 30
			
						//Traer la localización de WS según parametros
						Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
						If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
						//set ^zjb("ItemIns",12)="12 "_tSC
						Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
						//set ^zjb("ItemIns",13)="13 "_tSC
						Quit:$System.Status.IsError(tSC)
		
						Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
						//set ^zjb("ItemIns",14)="14 "_tSC
						Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
						//set ^zjb("ItemIns",15)="15 "_tSC
						set tDescripcionError = ""
						if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcionError = pResponse.ERPResponse.ErrorDescription
						//If $System.Status.IsError(tSC) Quit
			
						if pResponse.ERPResponse.IsError
						{
							//set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
							//Generar Traza para asociar al item de orden en caso de error y volver a enviar
							for i=1:1:tObjSend.Items.Count()
							{	
								set tOrderId = ""
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Error',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     DetalleError = :tDescripcionError
							 			 where %id = :tOrderId)
									
								}
							
							}			
						}
						else	
						{
							
							for i=1:1:tObjSend.Items.Count()
							{
								set (tOrderId,tNroERP) = ""
								if pResponse.ERPResponse.ErrorDescription '= "" set tNroERP = pResponse.ERPResponse.ErrorDescription
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Procesado en ERP',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     NroTransERP = :tNroERP,
							     		     DetalleError = null
							 			 where %id = :tOrderId)
								}
											
							}			
						}	
				
					}
			
				}
				
				
				&sql(fetch EnvioForzadoERP)
			}
			&sql(close EnvioForzadoERP)
			
		}
		
		
	} Catch(tException) {
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
		}
		Else
		{
			Set tSC =  tException.AsStatus()	
		}
		
	}
	//set ^zjb("NuevoEnvio","Error")="18 tSC "_tSC
	set tResp = tSC
	Quit tResp
}

/// inicio  reenvio automatico
ClassMethod EnvioDispToERPAutomatico() As %String
{
	Set tSC = $$$OK
	set tResp = tSC
	set pType="Grupo"
	set OrderId=""
	set OrderGroup="Todo"
	//set ^hernan("1")="automatico "_tSC
	
	Try
	{
		////set ^zjb("NuevoEnvio",0)="pType "_pType_" OrderId "_OrderId_" OrderGroup "_OrderGroup_" pUser "_pUser
		//If (pType = "Ind") && (OrderId = "")
		//{
		//	quit
		//}
		
		//If (pType = "Grupo") && (OrderGroup = "")
	//	{
			//quit
	//	}
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//set ^hernan("10")="automatico "_tIntegrationOn_" "_pType
		
		if pType = "Grupo"
		{
			//set ^zjb("NuevoEnvio",1)="OrderGroup "_OrderGroup
		    set ^hernan("11")="automatico "_tIntegrationOn_" "_pType
			&sql(declare EnvioERPa Cursor for
				 select distinct localCodeERP, NroDocumento,TipoMovimiento,Episodio, DetallePaciente, Ubicacion, CentroCosto,OrderGroupId,OrderRef
				 into :tLocalERP, :tNroDocumento, :tTipoMovimiento,:tEpisodio, :tDetallePaciente,:tUbicacion,:tCentroCosto,:OrderGroupNew,:OrderRef2
				 from Custom_User.DispensacionesERP
				 where  (EstadoEnvio = 'Ingresado' or EstadoEnvio = 'Error' or  EstadoEnvio = 'Enviado' )
				   and Cantidad > 0		
				   and NroTransERP is null		   
				   and FechaIngreso between current_Date -5 and current_Date-1
				   and  (DetalleError not like  '%Movimiento ya registrado en SAP%' and DetalleError not like  '%Moviento ya registrado en SAP%' and DetalleError not like  '%Quantity falls into negative inventory%' and DetalleError not like  '%Articulo no cuenta con stock suficiente%'
				   or DetalleError is null)
				   --and FechaIngreso between current_Date -136 and current_Date-1
				   --and FechaIngreso >= '2022-01-01'
				   --and localCodeERP= '020107'
				   --and CodigoERP in('13400105','13400202','900372','900440','900451','900695','900696','900698','900699','900700')
				     --and OrderGroupId in(2282163,2282164)
				  --and FechaIngreso =current_date 
				   --and HoraIngreso <= '15:00:00'
				 
				   order by OrderGroupId
				 )
				 
				 
				
				 
			&sql(open EnvioERPa)
			&sql(fetch EnvioERPa)
			
			//set ^hernan("12")="automatico "_tIntegrationOn_"  SQLCODE "_SQLCODE
			
			while SQLCODE = 0
			{
				set ind = 0
				  
				if tIntegrationOn
				{
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					set tObjSend.User ="integracion"
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroDocumento
					set tObjSend.MovementCode = tTipoMovimiento
					Set tObjSend.PatientName = tDetallePaciente
					Set tObjSend.Episode = tEpisodio
					Set tObjSend.LocationCode = tLocalERP
					Set tObjSend.CostCenter = tCentroCosto
					Set tObjSend.PatientLocation = tUbicacion
				//	set ^hernan("2")=tIntegrationOn
					
				}
				
				
				&sql(declare EnvioDetalleGrupoERPa Cursor for
				 	 select %id, Lote , FecVencimiento, Cantidad, CodigoERP,OrderRef->OEORI_ProsBatchNo,OrderRef->OEORI_ProsSerialNo,OrderRef->OEORI_ExpiryDate
				 	 into  :tid,:tLote,:tFecVencimiento, :tCantidad, :tCodigoERP, :tLote2, :tSerie2, :tFechaExp2 
				 	 from Custom_User.DispensacionesERP
				 	 where OrderRef = :OrderRef2
				       and TipoMovimiento = :tTipoMovimiento
				       and (EstadoEnvio = 'Ingresado' or EstadoEnvio = 'Error' or EstadoEnvio ='Enviado')
				       and localCodeERP = :tLocalERP
				       and NroDocumento = :tNroDocumento
				       and Cantidad > 0
				       order by CodigoERP
				     )
				
				&sql(open EnvioDetalleGrupoERPa)
				&sql(fetch EnvioDetalleGrupoERPa)
				while SQLCODE = 0
				{
					//set ^zjb("NuevoEnvio",2,tid)="tid "_tid
					//set ^hernan("3")="Entro al detalle"
					
					if tIntegrationOn
					{
						set ind = ind+1
						///Item
						set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
						set tObjSendItem.StockItemCode = tCodigoERP	
						set tObjSendItem.Quantity = tCantidad
						if tFecVencimiento = ""
						{
							if $get(tFechaExp2)'="" set tObjSendItem.ExpiryDate = tFechaExp2
						}
						else
						{
							set tObjSendItem.ExpiryDate = tFecVencimiento
						}
						
						if tLote = ""
						{
							if $get(tLote2)'="" set tObjSendItem.BatchNumber = tLote2
						}
						else
						{
							set tObjSendItem.BatchNumber = tLote
						}
						
						if $get(tSerie2) '= "" 
						{
							set tObjSendItem.MedicalProgram = tSerie2
						} 
						set tObjSendItem.SerialNumber = tid
				
						do tObjSend.Items.Insert(tObjSendItem)
						
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Activa',
							     EstadoEnvio = 'Enviado',
							     PosicionEnvio = :ind,
							     DetalleError = null						     
							 where %id = :tid)
						
					}
					else
					{
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Inactiva'
							 where %id = :tid)	
					}
					
					
					&sql(fetch EnvioDetalleGrupoERPa)
				}
				&sql(close EnvioDetalleGrupoERPa)
				
				
				///Envio mensaje
				if tIntegrationOn
				{
					if tObjSend.Items.Count() > 0 
					{
						// Enviar Mensaje
						Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
						Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
						set tWSSend.Timeout = 300
			
						//Traer la localización de WS según parametros
						Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
						If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
						//set ^zjb("ItemIns",12)="12 "_tSC
						Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
						//set ^zjb("ItemIns",13)="13 "_tSC
						Quit:$System.Status.IsError(tSC)
		
						Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
						//set ^zjb("ItemIns",14)="14 "_tSC
						Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
						//set ^zjb("ItemIns",15)="15 "_tSC
						set tDescripcionError = ""
						if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcionError = pResponse.ERPResponse.ErrorDescription
						//If $System.Status.IsError(tSC) Quit
			
						if pResponse.ERPResponse.IsError
						{
							set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
							//Generar Traza para asociar al item de orden en caso de error y volver a enviar
							for i=1:1:tObjSend.Items.Count()
							{	
								set tOrderId = ""
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Error',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     DetalleError = :tDescripcionError
							 			 where %id = :tOrderId)
									
								}
							
							}			
						}
						else	
						{
							
							for i=1:1:tObjSend.Items.Count()
							{
								set (tOrderId,tNroERP) = ""
								if pResponse.ERPResponse.ErrorDescription '= "" set tNroERP = pResponse.ERPResponse.ErrorDescription
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Procesado en ERP',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     NroTransERP = :tNroERP,
							     		     DetalleError = null
							 			 where %id = :tOrderId)
								}
											
							}			
						}	
				
					}
			
				}
				
				
				&sql(fetch EnvioERPa)
			}
			&sql(close EnvioERPa)
			
		}
		
					
		
	} Catch(tException) {
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			//set ^hernan("4")="automatico : "_tSC 
		}
		Else
		{
			Set tSC =  tException.AsStatus()
			//set ^hernan("5")="automatico ss : "_tSC 	
		}
		
	}
	//set ^zjb("NuevoEnvio","Error")="18 tSC "_tSC
	set tResp = tSC
	Quit tResp
}

/// fin reenvio automatico
/// inicio  reenvio automatico Dia
ClassMethod EnvioDispToERPAutomaticoDia() As %String
{
	Set tSC = $$$OK
	set tResp = tSC
	set pType="Grupo"
	set OrderId=""
	set OrderGroup="Todo"
	//set ^hernan("1")="automatico "_tSC
	
	Try
	{
		////set ^zjb("NuevoEnvio",0)="pType "_pType_" OrderId "_OrderId_" OrderGroup "_OrderGroup_" pUser "_pUser
		//If (pType = "Ind") && (OrderId = "")
		//{
		//	quit
		//}
		
		//If (pType = "Grupo") && (OrderGroup = "")
	//	{
			//quit
	//	}
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//set ^hernan("10")="automatico "_tIntegrationOn_" "_pType
		
		if pType = "Grupo"
		{
			//set ^zjb("NuevoEnvio",1)="OrderGroup "_OrderGroup
		    set ^hernan("11")="automatico "_tIntegrationOn_" "_pType
			&sql(declare EnvioERPa2 Cursor for
				 select distinct localCodeERP, NroDocumento,TipoMovimiento,Episodio, DetallePaciente, Ubicacion, CentroCosto,OrderGroupId,OrderRef
				 into :tLocalERP, :tNroDocumento, :tTipoMovimiento,:tEpisodio, :tDetallePaciente,:tUbicacion,:tCentroCosto,:OrderGroupNew,:OrderRef2
				 from Custom_User.DispensacionesERP
				 where EstadoEnvio = 'Error'
				   and Cantidad > 0		
				   and NroTransERP is null		   
				   and FechaIngreso = current_Date
				   and HoraIngreso <= '22:30:00'
				  and  (DetalleError not like  '%Movimiento ya registrado en SAP%' and DetalleError not like  '%Moviento ya registrado en SAP%' and DetalleError not like  '%Quantity falls into negative inventory%' and DetalleError not like  '%Articulo no cuenta con stock suficiente%'
				   or DetalleError is null)
				   --and CodigoERP  in('902292','901867','900256','901867','903317','905881')
				     --and OrderGroupId in(2282163,2282164)
				  --and FechaIngreso =current_date 
				   --and HoraIngreso <= '15:00:00'
				 
				   order by OrderGroupId
				 )
				 
				 
				
				 
			&sql(open EnvioERPa2)
			&sql(fetch EnvioERPa2)
			
			//set ^hernan("12")="automatico "_tIntegrationOn_"  SQLCODE "_SQLCODE
			
			while SQLCODE = 0
			{
				set ind = 0
				  
				if tIntegrationOn
				{
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					set tObjSend.User ="integracion"
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroDocumento
					set tObjSend.MovementCode = tTipoMovimiento
					Set tObjSend.PatientName = tDetallePaciente
					Set tObjSend.Episode = tEpisodio
					Set tObjSend.LocationCode = tLocalERP
					Set tObjSend.CostCenter = tCentroCosto
					Set tObjSend.PatientLocation = tUbicacion
				//	set ^hernan("2")=tIntegrationOn
					
				}
				
				
				&sql(declare EnvioDetalleGrupoERPa2 Cursor for
				 	 select %id, Lote , FecVencimiento, Cantidad, CodigoERP,OrderRef->OEORI_ProsBatchNo,OrderRef->OEORI_ProsSerialNo,OrderRef->OEORI_ExpiryDate
				 	 into  :tid,:tLote,:tFecVencimiento, :tCantidad, :tCodigoERP, :tLote2, :tSerie2, :tFechaExp2 
				 	 from Custom_User.DispensacionesERP
				 	 where OrderRef = :OrderRef2
				       and TipoMovimiento = :tTipoMovimiento
				       and (EstadoEnvio = 'Ingresado' or EstadoEnvio = 'Error' or EstadoEnvio ='Enviado')
				       and localCodeERP = :tLocalERP
				       and NroDocumento = :tNroDocumento
				       and Cantidad > 0
				       order by CodigoERP
				     )
				
				&sql(open EnvioDetalleGrupoERPa2)
				&sql(fetch EnvioDetalleGrupoERPa2)
				while SQLCODE = 0
				{
					//set ^zjb("NuevoEnvio",2,tid)="tid "_tid
					//set ^hernan("3")="Entro al detalle"
					
					if tIntegrationOn
					{
						set ind = ind+1
						///Item
						set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
						set tObjSendItem.StockItemCode = tCodigoERP	
						set tObjSendItem.Quantity = tCantidad
						if tFecVencimiento = ""
						{
							if $get(tFechaExp2)'="" set tObjSendItem.ExpiryDate = tFechaExp2
						}
						else
						{
							set tObjSendItem.ExpiryDate = tFecVencimiento
						}
						
						if tLote = ""
						{
							if $get(tLote2)'="" set tObjSendItem.BatchNumber = tLote2
						}
						else
						{
							set tObjSendItem.BatchNumber = tLote
						}
						
						if $get(tSerie2) '= "" 
						{
							set tObjSendItem.MedicalProgram = tSerie2
						} 
						set tObjSendItem.SerialNumber = tid
				
						do tObjSend.Items.Insert(tObjSendItem)
						
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Activa',
							     EstadoEnvio = 'Enviado',
							     PosicionEnvio = :ind,
							     DetalleError = null						     
							 where %id = :tid)
						
					}
					else
					{
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Inactiva'
							 where %id = :tid)	
					}
					
					
					&sql(fetch EnvioDetalleGrupoERPa2)
				}
				&sql(close EnvioDetalleGrupoERPa2)
				
				
				///Envio mensaje
				if tIntegrationOn
				{
					if tObjSend.Items.Count() > 0 
					{
						// Enviar Mensaje
						Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
						Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
						set tWSSend.Timeout = 180
			
						//Traer la localización de WS según parametros
						Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
						If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
						//set ^zjb("ItemIns",12)="12 "_tSC
						Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
						//set ^zjb("ItemIns",13)="13 "_tSC
						Quit:$System.Status.IsError(tSC)
		
						Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
						//set ^zjb("ItemIns",14)="14 "_tSC
						Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
						//set ^zjb("ItemIns",15)="15 "_tSC
						set tDescripcionError = ""
						if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcionError = pResponse.ERPResponse.ErrorDescription
						//If $System.Status.IsError(tSC) Quit
			
						if pResponse.ERPResponse.IsError
						{
							set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
							//Generar Traza para asociar al item de orden en caso de error y volver a enviar
							for i=1:1:tObjSend.Items.Count()
							{	
								set tOrderId = ""
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Error',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     DetalleError = :tDescripcionError
							 			 where %id = :tOrderId)
									
								}
							
							}			
						}
						else	
						{
							
							for i=1:1:tObjSend.Items.Count()
							{
								set (tOrderId,tNroERP) = ""
								if pResponse.ERPResponse.ErrorDescription '= "" set tNroERP = pResponse.ERPResponse.ErrorDescription
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Procesado en ERP',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     NroTransERP = :tNroERP,
							     		     DetalleError = null
							 			 where %id = :tOrderId)
								}
											
							}			
						}	
				
					}
			
				}
				
				
				&sql(fetch EnvioERPa2)
			}
			&sql(close EnvioERPa2)
			
		}
		
					
		
	} Catch(tException) {
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			//set ^hernan("4")="automatico : "_tSC 
		}
		Else
		{
			Set tSC =  tException.AsStatus()
			//set ^hernan("5")="automatico ss : "_tSC 	
		}
		
	}
	//set ^zjb("NuevoEnvio","Error")="18 tSC "_tSC
	set tResp = tSC
	Quit tResp
}

/// fin reenvio automatico Dia
ClassMethod ReturnOmnicell2(OrderIds, pQty, pUserId) As %String
{
	Set tSC = $$$OK
	set pUsuario = ""
	if pUserId '= "" set pUsuario = $piece(^SSU("SSUSR",pUserId),"^",1)
	if pUsuario = "" set pUsuario = "intDisp"
	set tUserToSendERP = ""
	if OrderIds = "" Quit tSC
	Try
	{
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		set tgroupId = $i(^HMSDispensacionGroup)
		while tId '=""
		{	
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue
			}
			set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
			set tObjToInsert.OrderGroupId = tgroupId
			set tObjToInsert.OrderRef = tObjOrder
			
			//Cantidad
			set tObjToInsert.Cantidad = pQty
			
			//Tipo Movimiento 
			set tObjToInsert.TipoMovimiento = "S003"
				
			//Locales 
			set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
					
			if $IsObject(tObjOrder.OEORIRecDepDR)
			{	
				Set tObjLocal = tObjOrder.OEORIRecDepDR
			}
					
			if $IsObject(tObjLocal)
			{
				Set tLocalERP = tObjLocal.CTLOCPagerNo
				if $IsObject(tObjLocal.CTLOCGLCCCDR)
				{
					set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
				}
					
				set tObjToInsert.LocalTrak = tObjLocal
				set tObjToInsert.LocalCodeERP = tLocalERP
				set tObjToInsert.CentroCosto = tCentroCosto
				set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
			}
				
			//Nro Documento
			set (NroDoumento)=""
			set tNroDocumento = tObjOrder.OEORIPrescNo
			if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
			set tObjToInsert.NroDocumento = tNroDocumento
			
			//Usuario
			set tUserToSendERP = ""
			set tUserToSendERP =..GetDispUserToSendERP()
			if tUserToSendERP = ""
			{
				set tUserToSendERP = pUsuario
			}
			
			set tObjToInsert.Usuario = 	pUsuario
			
			//Episodio
			set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
			//Paciente
			set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
			if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
			{
				set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
				
				Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			}
			
			
			///Datos Item
			set tCodERP = ""
			set tOEORIItmMastDR = tObjOrder.OEORIItmMastDR.%Id()
			set tCodItemMast = tObjOrder.OEORIItmMastDR.ARCIMCode
						
			//Codigo Externo
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
			}
						
			//Si no existe Homologacion se manda el codigo del item
			if tCodERP = "" set tCodERP = tCodItemMast
			set tObjToInsert.CodigoERP = tCodERP
										
			set tObjToInsert.Lote = ""
			set tObjToInsert.FecVencimiento = ""
						
			set tObjToInsert.CantIntentos = 0
			set tObjToInsert.EstadoEnvio = "Ingresado"
			set tObjToInsert.ProcIngreso = "ReturnOmnicell2 Omn"
				
			set tSC = tObjToInsert.%Save()	
						
			do ##class(Custom.ERP.StockHandler).UpdateManualStock(tObjOrder.OEORIRecDepDR.%Id(),tObjOrder.OEORIItmMastDR.ARCIMCode,pQty,"-","","")
								
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
	
		if tUserToSendERP = "" set tUserToSendERP = pUsuario
		set tResp = ..EnvioDispToERP("Grupo", "", tgroupId, tUserToSendERP)
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
	}
		
	Quit tSC
}

ClassMethod ListShowNroDoc(pRS) As %Integer
{
	
	set tName = $Order(pRS.Data(""))
    

	set (tId, tObjId,tPresc,tSubcatType,tNroDocAlt) = ""
	set tPresc = $get(pRS.Data("PrescriptionNo")) 
	
	set ^zjb("listnoshow",1)= "tPresc "_tPresc
	if tPresc '= "" quit 1
	
	set tId = $get(pRS.Data("ID"))
	
	set ^zjb("listnoshow",2)= "tId "_tId
	if tId = "" quit 1
	
	set tObjId = ##class(User.OEOrdItem).%OpenId(tId)
		
	if '$IsObject(tObjId) quit 1
	if '$IsObject(tObjId.OEORIItmMastDR.ARCIMItemCatDR) quit 1
	set tSubcatType = tObjId.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrderType
	set ^zjb("listnoshow",3,tId)= "tSubcatType "_tSubcatType
	if (tSubcatType = "R")||(tSubcatType="I")
	{
		set tNroDocAlt = tObjId.OEORIBBExtCode
		
		if tNroDocAlt '= ""
		{
			set pRS.Data("ExtPrescNo") = tNroDocAlt
		}
		
	}
	
	quit 1
}

ClassMethod SendMailToOmnicell(pFecha, pBodOrigen, pBodDestino, pMails) As %String
{
	
	set ^zjb("SendMail",1)="1 pFecha "_pFecha_" pBodOrigen "_pBodOrigen_" pBodDestino "_pBodDestino_" pMails "_pMails
	set tResp = 0
	set tConta = 0

	Try
	{

		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.EnvioMailOmnicellG4")
		//Salir si no está activa la integracion
		if 'tIntegrationOn 
		{
			set tResp = "Integracion Inactiva"
			Quit	
		}
		
		if pMails = ""
		{
			set tResp="Debe Indicar al menos un mail"
			quit
		}
		
		set (tFecha,tBodegaOrigenCode,tBodegadestinoCode,tBodegaOrigenId,tBodegadestinoId) = ""
		if pFecha'="" set tFecha=$replace(pFecha,"/","-")
		if tFecha '= "" set tFecha = $piece(tFecha,"-",3)_"-"_$piece(tFecha,"-",2)_"-"_$piece(tFecha,"-",1)
		
		if pBodDestino'="" set tBodegadestinoId = ##class(web.CTLoc).GetIdFromCodeDescriptionHosp(pBodDestino)
		if tBodegadestinoId '= "" set tBodegadestinoCode = $piece(^CTLOC(+tBodegadestinoId),"^",1)
		
		if pBodOrigen'="" set tBodegaOrigenId = ##class(web.CTLoc).GetIdFromCodeDescriptionHosp(pBodOrigen)
		if tBodegaOrigenId '= "" set tBodegaOrigenCode = $piece(^CTLOC(+tBodegaOrigenId),"^",1)
		
		
		Set tWSSend = ##class(Custom.ERP.SendMailOmnicell.SendEmailServiceSoap).%New()
		
		//Traer la localización de WS según parametros
		Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.EnvioMailOmnicellG4")
		If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
		
		
		set tObjSend = ##class(Custom.ERP.SendMailOmnicell.s0.SendMailRequest).%New()
		set tObjSend.BodegaDestino = tBodegadestinoCode
		set tObjSend.BodegaOrigen = tBodegaOrigenCode
		set tObjSend.Date = tFecha
		set tObjSend.Destinatarios = pMails
		set tObjSend.TipoEnvio = "Manual"
		set tObjSend.Usuario = $g(%session.Data("LOGON.USERNAME"))
		
		Set pResponse = ##class(Custom.ERP.SendMailOmnicell.s0.Response).%New()
		Set RespWS = tWSSend.SendMailFromTrak(tObjSend,.pResponse)
		
		set ^zjb("SendMail",2)= " RespWS "_RespWS_" pResponse "_pResponse.IsError_" pResponseDesc "_pResponse.ErrorDescription
		
		set tResp = "Proceso de envio en proceso, revise en unos minutos el correo"
		
	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		//set ^zjb("SendTransferToKardex",3)= tSC
		Set tResp = "Ha ocurrido un error en el proceso, contactese con Informática"
		
		
	}
	
	Quit tResp
}

// inicio envio automatico 2 

ClassMethod EnvioDispToERPAutomatico30diasantes() As %String
{
	Set tSC = $$$OK
	set tResp = tSC
	set pType="Grupo"
	set OrderId=""
	set OrderGroup="Todo"
	//set ^hernan("1")="automatico "_tSC
	
	Try
	{
		////set ^zjb("NuevoEnvio",0)="pType "_pType_" OrderId "_OrderId_" OrderGroup "_OrderGroup_" pUser "_pUser
		//If (pType = "Ind") && (OrderId = "")
		//{
		//	quit
		//}
		
		//If (pType = "Grupo") && (OrderGroup = "")
	//	{
			//quit
	//	}
		
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		//set ^hernan("10")="automatico "_tIntegrationOn_" "_pType
		
		if pType = "Grupo"
		{
			//set ^zjb("NuevoEnvio",1)="OrderGroup "_OrderGroup
		    set ^hernan("11")="automatico "_tIntegrationOn_" "_pType
			&sql(declare EnvioERPa30 Cursor for
				 select distinct localCodeERP, NroDocumento,TipoMovimiento,Episodio, DetallePaciente, Ubicacion, CentroCosto,OrderGroupId,OrderRef
				 into :tLocalERP, :tNroDocumento, :tTipoMovimiento,:tEpisodio, :tDetallePaciente,:tUbicacion,:tCentroCosto,:OrderGroupNew,:OrderRef2
				 from Custom_User.DispensacionesERP
				 where  (EstadoEnvio = 'Ingresado' or EstadoEnvio = 'Error' or  EstadoEnvio = 'Enviado' )
				   and Cantidad > 0		
				   and NroTransERP is null		   
				   and FechaIngreso between current_Date-30  and current_Date-2
				   and  (DetalleError not like  '%Movimiento ya registrado en SAP InventoryGenExits%' 
				    and DetalleError not like  '%Quantity falls into negative inventory%'  or DetalleError is null)
				   --and CodigoERP  in('902292','901867','900256','901867','903317','905881')
				     --and OrderGroupId in(2282163,2282164)
				  --and FechaIngreso =current_date 
				   --and HoraIngreso <= '15:00:00'
				 
				   order by OrderGroupId
				 )
				 
				 
				
				 
			&sql(open EnvioERPa30)
			&sql(fetch EnvioERPa30)
			
			//set ^hernan("12")="automatico "_tIntegrationOn_"  SQLCODE "_SQLCODE
			
			while SQLCODE = 0
			{
				set ind = 0
				  
				if tIntegrationOn
				{
					set tObjSend = ##class(Custom.ERP.WS.s0.StockEvent).%New()
					set tObjSend.User ="integracion"
					set tObjSend.FacilityCode = 1000
					set tObjSend.DocumentNo = tNroDocumento
					set tObjSend.MovementCode = tTipoMovimiento
					Set tObjSend.PatientName = tDetallePaciente
					Set tObjSend.Episode = tEpisodio
					Set tObjSend.LocationCode = tLocalERP
					Set tObjSend.CostCenter = tCentroCosto
					Set tObjSend.PatientLocation = tUbicacion
				//	set ^hernan("2")=tIntegrationOn
					
				}
				
				
				&sql(declare EnvioDetalleGrupoERPa30 Cursor for
				 	 select %id, Lote , FecVencimiento, Cantidad, CodigoERP
				 	 into  :tid,:tLote,:tFecVencimiento, :tCantidad, :tCodigoERP
				 	 from Custom_User.DispensacionesERP
				 	 where OrderRef = :OrderRef2
				       and TipoMovimiento = :tTipoMovimiento
				       and (EstadoEnvio = 'Ingresado' or EstadoEnvio = 'Error' or EstadoEnvio ='Enviado')
				       and localCodeERP = :tLocalERP
				       and NroDocumento = :tNroDocumento
				       and Cantidad > 0
				       order by CodigoERP
				     )
				
				&sql(open EnvioDetalleGrupoERPa30)
				&sql(fetch EnvioDetalleGrupoERPa30)
				while SQLCODE = 0
				{
					//set ^zjb("NuevoEnvio",2,tid)="tid "_tid
					//set ^hernan("3")="Entro al detalle"
					
					if tIntegrationOn
					{
						set ind = ind+1
						///Item
						set tObjSendItem = ##class(Custom.ERP.WS.s0.StockItems).%New()
				
						set tObjSendItem.StockItemCode = tCodigoERP	
						set tObjSendItem.Quantity = tCantidad
						set tObjSendItem.ExpiryDate = tFecVencimiento
						set tObjSendItem.BatchNumber = tLote
						set tObjSendItem.SerialNumber = tid
				
						do tObjSend.Items.Insert(tObjSendItem)
						
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Activa',
							     EstadoEnvio = 'Enviado',
							     PosicionEnvio = :ind,
							     DetalleError = null					     
							 where %id = :tid)
						
					}
					else
					{
						&sql(Update %nolock Custom_User.DispensacionesERP
							 set CantIntentos = CantIntentos+1,
							     FechaUltimoIntento = current_date,
							     HoraUltimoIntento = current_time,
							     EstadoIntegracion = 'Inactiva'
							 where %id = :tid)	
					}
					
					
					&sql(fetch EnvioDetalleGrupoERPa30)
				}
				&sql(close EnvioDetalleGrupoERPa30)
				
				
				///Envio mensaje
				if tIntegrationOn
				{
					if tObjSend.Items.Count() > 0 
					{
						// Enviar Mensaje
						Set pResponse = ##class(Custom.ERP.WS.s0.StockEvent).%New()
						Set tWSSend = ##class(Custom.ERP.WS.StockServiceSoap).%New()
						set tWSSend.Timeout = 300
			
						//Traer la localización de WS según parametros
						Set tConfigLocation = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("WS.Integracion.StockFarmacia")
						If tConfigLocation'="" Set tWSSend.Location=tConfigLocation
			
			
						//set ^zjb("ItemIns",12)="12 "_tSC
						Set tSC = ##class(Custom.Nexus.Facade.Nexus).GetNexusWSAuthenticationData(.tEnsembleUserName, .tEnsemblePassword)
						//set ^zjb("ItemIns",13)="13 "_tSC
						Quit:$System.Status.IsError(tSC)
		
						Set tSC = tWSSend.WSSecurityLogin(tEnsembleUserName,tEnsemblePassword)		
						//set ^zjb("ItemIns",14)="14 "_tSC
						Set tSC = tWSSend.SendEvent(tObjSend,.pResponse)
		
						//set ^zjb("ItemIns",15)="15 "_tSC
						set tDescripcionError = ""
						if pResponse.ERPResponse.ErrorDescription '= "" set tDescripcionError = pResponse.ERPResponse.ErrorDescription
						//If $System.Status.IsError(tSC) Quit
			
						if pResponse.ERPResponse.IsError
						{
							set ^zjb("Error",1)="1 "_tObjSend.DocumentNo
							//Generar Traza para asociar al item de orden en caso de error y volver a enviar
							for i=1:1:tObjSend.Items.Count()
							{	
								set tOrderId = ""
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Error',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     DetalleError = :tDescripcionError
							 			 where %id = :tOrderId)
									
								}
							
							}			
						}
						else	
						{
							
							for i=1:1:tObjSend.Items.Count()
							{
								set (tOrderId,tNroERP) = ""
								if pResponse.ERPResponse.ErrorDescription '= "" set tNroERP = pResponse.ERPResponse.ErrorDescription
								set tOrderId = tObjSend.Items.GetAt(i).SerialNumber
								if tOrderId '= ""
								{
									&sql(Update %nolock Custom_User.DispensacionesERP
							     		 set EstadoEnvio = 'Procesado en ERP',
							     		     FechaRespuesta = Current_Date,
							     		     HoraRespuesta = Current_Time,
							     		     NroTransERP = :tNroERP,
							     		     DetalleError = null
							 			 where %id = :tOrderId)
								}
											
							}			
						}	
				
					}
			
				}
				
				
				&sql(fetch EnvioERPa30)
			}
			&sql(close EnvioERPa30)
			
		}
		
					
		
	} Catch(tException) {
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			//set ^hernan("4")="automatico : "_tSC 
		}
		Else
		{
			Set tSC =  tException.AsStatus()
			//set ^hernan("5")="automatico ss : "_tSC 	
		}
		
	}
	//set ^zjb("NuevoEnvio","Error")="18 tSC "_tSC
	set tResp = tSC
	Quit tResp
}

/// fin reenvio automatico 2
ClassMethod SentToERPFromOmnicell2(OrderIds, pQty, pLocalId, pUsuario As %String = "intDisp") As %Status
{
	
	Set tSC = $$$OK
	
	if pUsuario = "" set pUsuario = "intDisp"
	set tUserToSendERP = ""
	if OrderIds = "" Quit tSC
	if pLocalId = "" Quit tSC
	Try
	{
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		set tgroupId = $i(^HMSDispensacionGroup)
		while tId '=""
		{	
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue
			}
			
			set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
			set tObjToInsert.OrderGroupId = tgroupId
			set tObjToInsert.OrderRef = tObjOrder
			
			//Cantidad
			set tObjToInsert.Cantidad = pQty
			
			//Tipo Movimiento 
			set tObjToInsert.TipoMovimiento = "S002"
				
			//Local, dejar fijo el local de Omnicell para casos de recetas dispensadas en un local distinto
			set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
			
			/*		
			if $IsObject(tObjOrder.OEORIRecDepDR)
			{	
				Set tObjLocal = tObjOrder.OEORIRecDepDR
			}
			*/
			
			if pLocalId '= "" set tObjLocal = ##class(User.CTLoc).%OpenId(pLocalId)
					
			if $IsObject(tObjLocal)
			{
				Set tLocalERP = tObjLocal.CTLOCPagerNo
				if $IsObject(tObjLocal.CTLOCGLCCCDR)
				{
					set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
				}
					
				set tObjToInsert.LocalTrak = tObjLocal
				set tObjToInsert.LocalCodeERP = tLocalERP
				set tObjToInsert.CentroCosto = tCentroCosto
				set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
			}
				
			//Nro Documento
			set (NroDoumento)=""
			set tNroDocumento = tObjOrder.OEORIPrescNo
			if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
			set tObjToInsert.NroDocumento = tNroDocumento
				
			
			//Usuario
			set tUserToSendERP = ""
			set tUserToSendERP =..GetDispUserToSendERP()
			if tUserToSendERP = ""
			{
				set tUserToSendERP = pUsuario
			}
			set tObjToInsert.Usuario = 	tUserToSendERP
			
			//Episodio
			set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
			//Paciente
			set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
			if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
			{
				set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
				
				Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			}
			
			
			///Datos Item
			set tCodERP = ""
			set tOEORIItmMastDR = tObjOrder.OEORIItmMastDR.%Id()
			set tCodItemMast = tObjOrder.OEORIItmMastDR.ARCIMCode
						
			//Codigo Externo
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
			}
						
			//Si no existe Homologacion se manda el codigo del item
			if tCodERP = "" set tCodERP = tCodItemMast
			set tObjToInsert.CodigoERP = tCodERP
			
										
			set tObjToInsert.Lote = ""
			set tObjToInsert.FecVencimiento = ""
						
			set tObjToInsert.CantIntentos = 0
			set tObjToInsert.EstadoEnvio = "Ingresado"
			set tObjToInsert.ProcIngreso = "SentToERPFromOmnicell2"
				
			set tSC = tObjToInsert.%Save()	
						
			do ##class(Custom.ERP.StockHandler).UpdateManualStock(tObjOrder.OEORIRecDepDR.%Id(),tObjOrder.OEORIItmMastDR.ARCIMCode,pQty,"-","","")
								
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
	
		if tUserToSendERP = "" set tUserToSendERP = pUsuario
		set tResp = ..EnvioDispToERP("Grupo", "", tgroupId, tUserToSendERP)
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
		//set ^zjb("ItemIns",17)="17 tSC "_tSC
		
	}
		
	//set ^zjb("ItemIns",18)="18 tSC "_tSC	
	Quit tSC
}

ClassMethod ReturnOmnicell2Ajuste(OrderIds, pQty, pLocalId, pUserId) As %String
{
	Set tSC = $$$OK
	set pUsuario = ""
	if pUserId '= "" set pUsuario = $piece(^SSU("SSUSR",pUserId),"^",1)
	if pUsuario = "" set pUsuario = "intDisp"
	set tUserToSendERP = ""
	if OrderIds = "" Quit tSC
	Try
	{
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		set tgroupId = $i(^HMSDispensacionGroup)
		while tId '=""
		{	
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue
			}
			set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
			set tObjToInsert.OrderGroupId = tgroupId
			set tObjToInsert.OrderRef = tObjOrder
			
			//Cantidad
			set tObjToInsert.Cantidad = pQty
			
			//Tipo Movimiento 
			set tObjToInsert.TipoMovimiento = "S003"
				
			//Locales 
			set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
			/*		
			if $IsObject(tObjOrder.OEORIRecDepDR)
			{	
				Set tObjLocal = tObjOrder.OEORIRecDepDR
			}
			*/
			if pLocalId '= "" set tObjLocal = ##class(User.CTLoc).%OpenId(pLocalId)
					
			if $IsObject(tObjLocal)
			{
				Set tLocalERP = tObjLocal.CTLOCPagerNo
				if $IsObject(tObjLocal.CTLOCGLCCCDR)
				{
					set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
				}
					
				set tObjToInsert.LocalTrak = tObjLocal
				set tObjToInsert.LocalCodeERP = tLocalERP
				set tObjToInsert.CentroCosto = tCentroCosto
				set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
			}
				
			//Nro Documento
			set (NroDoumento)=""
			set tNroDocumento = tObjOrder.OEORIPrescNo
			if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
			set tObjToInsert.NroDocumento = tNroDocumento
			
			//Usuario
			set tUserToSendERP = ""
			set tUserToSendERP =..GetDispUserToSendERP()
			if tUserToSendERP = ""
			{
				set tUserToSendERP = pUsuario
			}
			
			set tObjToInsert.Usuario = 	pUsuario
			
			//Episodio
			set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
			//Paciente
			set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
			if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
			{
				set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
				
				Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			}
			
			
			///Datos Item
			set tCodERP = ""
			set tOEORIItmMastDR = tObjOrder.OEORIItmMastDR.%Id()
			set tCodItemMast = tObjOrder.OEORIItmMastDR.ARCIMCode
						
			//Codigo Externo
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
			}
						
			//Si no existe Homologacion se manda el codigo del item
			if tCodERP = "" set tCodERP = tCodItemMast
			set tObjToInsert.CodigoERP = tCodERP
										
			set tObjToInsert.Lote = ""
			set tObjToInsert.FecVencimiento = ""
						
			set tObjToInsert.CantIntentos = 0
			set tObjToInsert.EstadoEnvio = "Ingresado"
			set tObjToInsert.ProcIngreso = "ReturnOmnicell2 Omn"
				
			set tSC = tObjToInsert.%Save()	
						
			do ##class(Custom.ERP.StockHandler).UpdateManualStock(tObjOrder.OEORIRecDepDR.%Id(),tObjOrder.OEORIItmMastDR.ARCIMCode,pQty,"-","","")
								
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
	
		if tUserToSendERP = "" set tUserToSendERP = pUsuario
		set tResp = ..EnvioDispToERP("Grupo", "", tgroupId, tUserToSendERP)
		
	} Catch(tException) {
		Set tSC = tException.AsStatus()	
	}
		
	Quit tSC
}

ClassMethod ReturnToERPBodegasPerifesricas(OrderIds) As %Status
{
	Set tSC = $$$OK
	if OrderIds = "" Quit tSC
	Try
	{
		set ind = 1
		set tId = $piece(OrderIds,",",ind)
		set ord = $p(tId,"||",1)
		set itm = $p(tId,"||",2)
		
		set InsCount = 1
		set tgroupId = $i(^HMSDispensacionGroup)
		while tId '=""
		{	
			set tObjOrder = ##class(User.OEOrdItem).%OpenId(tId)
			if '$IsObject(tObjOrder)
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue
			}
			
			///Seguir solo si el local receptor es de tipo de dispensacion Bodega Peridferica
			if $IsObject(tObjOrder.OEORIRecDepDR)
			{
				if tObjOrder.OEORIRecDepDR.CTLOCExternalInfoSystem'="SONA"
				{
					set ind = ind+1
					set tId = $piece(OrderIds,",",ind)
					set ord = $p(tId,"||",1)
					set itm = $p(tId,"||",2)
					continue
				}
			}
			else
			{
				set ind = ind+1
				set tId = $piece(OrderIds,",",ind)
				set ord = $p(tId,"||",1)
				set itm = $p(tId,"||",2)
				continue
			}
			
			
			///Seguir solo si es suspendido
			if $IsObject(tObjOrder.OEORIItemStatDR)
			{
				if tObjOrder.OEORIItemStatDR.OSTATCode'="D"
				{
					set ind = ind+1
					set tId = $piece(OrderIds,",",ind)
					set ord = $p(tId,"||",1)
					set itm = $p(tId,"||",2)
					continue
				}
			}
			
			set tObjToInsert = ##class(Custom.User.DispensacionesERP).%New()
			set tObjToInsert.OrderGroupId = tgroupId
			set tObjToInsert.OrderRef = tObjOrder
					
			//Cantidad
			set (tCantidad,tSubcategoriaType) = ""
			set tSubcategoriaType = tObjOrder.OEORIItmMastDR.ARCIMItemCatDR.ARCICOrderType
			if ($g(tSubcategoriaType) = "R") || ($g(tSubcategoriaType) = "I")
			{
				set tCantidad = 0
				set qty=$piece($get(^OEORD(ord,"I",itm,1)),"^",12)
	 			set uom=$piece($get(^OEORD(ord,"I",itm,2)),"^",3)
	 			set arcim=$piece($get(^OEORD(ord,"I",itm,1)),"^",2)
	 			set drgform=$piece($get(^ARCIM(+arcim,1,1)),"^",12)
				set tCantidad = $$calcqty^aOET7(drgform,uom,qty)
					
			}
			else
			{
				set tCantidad =  tObjOrder.OEORIPhQtyOrd
			}
			set tObjToInsert.Cantidad = tCantidad
				
			//Tipo Movimiento 
			set tObjToInsert.TipoMovimiento = "S003"
				
			//Locales 
			set (tLocal,tObjLocal,tCentroCosto,tLocalERP)=""
					
			if $IsObject(tObjOrder.OEORIRecDepDR)
			{	
				Set tObjLocal = tObjOrder.OEORIRecDepDR
			}
					
			if $IsObject(tObjLocal)
			{
				Set tLocalERP = tObjLocal.CTLOCPagerNo
				if $IsObject(tObjLocal.CTLOCGLCCCDR)
				{
					set tCentroCosto = tObjLocal.CTLOCGLCCCDR.GLCCCCode 
				}
					
				set tObjToInsert.LocalTrak = tObjLocal
				set tObjToInsert.LocalCodeERP = tLocalERP
				set tObjToInsert.CentroCosto = tCentroCosto
				set tObjToInsert.TipoBodega = tObjLocal.CTLOCExternalInfoSystem
					
			}
				
			//Nro Documento
			set (NroDoumento)=""
			set tNroDocumento = tObjOrder.OEORIPrescNo
			if tNroDocumento="" set tNroDocumento = tObjOrder.OEORIBBExtCode
			set tObjToInsert.NroDocumento = tNroDocumento
				
			//Usuario
			set tObjToInsert.Usuario = $g(%session.Data("LOGON.USERCODE"))
				
				
			//Episodio
			set tObjToInsert.Episodio = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMADMNo
				
			//Paciente
			set tObjToInsert.Ubicacion = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMCurrentBedDR.BEDCode
				
			if $IsObject(tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR)
			{
				set PAADMPAPMIDR = tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.%Id()
				set (tRtMastId,tFicha) = ""
				set tRtMastId = $order(^RT(0,"PAT",PAADMPAPMIDR,""))
				if tRtMastId '= ""
				{
					set tFicha = $piece(^RT(tRtMastId),"^",1)
				}
				
				Set tObjToInsert.DetallePaciente = tFicha_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERID_"/"_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName2_" "_tObjOrder.OEORIOEORDParRef.OEORDAdmDR.PAADMPAPMIDR.PAPMIRowId.PAPERName
			}

				
			///Datos Item
			set tCodERP = ""
			set tOEORIItmMastDR = tObjOrder.OEORIItmMastDR.%Id()
			set tCodItemMast = tObjOrder.OEORIItmMastDR.ARCIMCode
						
			//Codigo Externo
			set tLocalHomologacionERP = ##class(Custom.Nexus.CS.ConfigRegistry).GetConfigValueFor("Local.ERP.SAP")
			set tLocalHomologacionERP = "SAP"
			if tLocalHomologacionERP '=""
			{
				set tERPLocationId = ##class(web.CTLoc).GetIdFromCodeOrDescription(tLocalHomologacionERP)
				set tCodERP = ..GetItemExtCodeByLoc(tOEORIItmMastDR,tERPLocationId)
			}
						
			//Si no existe Homologacion se manda el codigo del item
			if tCodERP = "" set tCodERP = tCodItemMast
			set tObjToInsert.CodigoERP = tCodERP
			
										
			set tObjToInsert.Lote = ""
			set tObjToInsert.FecVencimiento = ""
						
			set tObjToInsert.CantIntentos = 0
			set tObjToInsert.EstadoEnvio = "Ingresado"
			set tObjToInsert.ProcIngreso = "ReturnToERPBodegasPerifesricas-OEOrder.Custom"
				
			set tSC = tObjToInsert.%Save()
			
			
			
			set ind = ind+1
			set tId = $piece(OrderIds,",",ind)
			set ord = $p(tId,"||",1)
			set itm = $p(tId,"||",2)
		}
		
		set tResp = ..EnvioDispToERP("Grupo", "", tgroupId,$g(%session.Data("LOGON.USERCODE")))

	} 
	Catch(tException) 
	{
		Set tSC = tException.AsStatus()	
		
	}
	//set ^zjb("NewPeris","Error")=tSC
	
	Quit tSC
}

ClassMethod StockGetUpdateFromQueryDual(pLocationDescription, pItemDescription) As %String
{
	
	Set tSC = $$$OK
	Set resp = "1"
	//set ^zjb("ConsDual",1)="pLocationDescription "_pLocationDescription_" pItemDescription "_pItemDescription
	#dim pResponse As Custom.ERP.WS.s0.StockEvent
	Try
	{
		set (tCantidadOMN,tCantidadERP)="No disponible"
		set tIntegrationOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("WS.Integracion.StockFarmacia")
		set tOMNIOn = ##class(Custom.Nexus.CS.ConfigRegistry).GetActive("OMNI.WS.StockFarmacia") 
		if pLocationDescription = "" 
		{
			set res = "0^Local/Bodega es Obligatorio"
			quit
		}
		if pItemDescription = "" 
		{
			set res = "0^Items es Obligatorio"
			quit
		}
		
		//set ^zjb("ConsDual",2)="resp "_resp
		//busca datos del local receptor
		set (tLoc,tERPLoc,tOMNIArea,tLocCode,tDispType,tExtSystemType,tHL7Outbound) = ""
		&SQL(SELECT CTLOC_RowID, CTLOC_PagerNo, CTLOC_TelephoneExt, CTLOC_Code,CTLOC_ExternalInfoSystem,CTLOC_HL7OrdersLink
			INTO :tLoc, :tERPLoc, :tOMNIArea, :tLocCode,:tExtSystemType,:tHL7Outbound
			FROM SQLUser.CT_Loc
			WHERE  (%ALPHAUP CTLOC_Desc = %ALPHAUP :pLocationDescription)
			)

		if tERPLoc ="" && tOMNIArea="" quit
		
		//set ^zjb("ConsDual",3)="resp "_resp
				
		//busca datos del item de stock		
		set (tINCIId,tARCIMCode) = ""
		&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  (%ALPHAUP INCI_Desc = %ALPHAUP :pItemDescription)
			)
		if SQLCODE'=0 set tINCIId = ""
		
		//set ^zjb("ConsDual",4)="tIntegrationOn "_tIntegrationOn_" tOMNIOn "_tOMNIOn
		if tINCIId = ""
		{
			&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  (%ALPHAUP INCI_Code = %ALPHAUP :pItemDescription)
			)
			if SQLCODE'=0 set tINCIId = ""
		}
		
		if tINCIId = ""
		{
			&SQL(SELECT %id, INCI_Code
			INTO :tINCIId, :tARCIMCode
			FROM SQLUser.INC_Itm
			WHERE  %id = :pItemDescription
			)
			if SQLCODE'=0 set tINCIId = ""
		}
		
		if tINCIId ="" || tARCIMCode="" quit
		
		
		set tTimeUpdate = 1
		//set tTimeUpdate = ..ValidateTimeUpdate(tINCIId,tLoc,"INCI","1",tDispType)
		set tTimeUpdate = ..ValidateTimeUpdate(tINCIId,tLoc,"INCI","1")
		if tTimeUpdate = 0 quit
		
		
		// Busca saldo de stock via integracion
		if tOMNIOn
		{
			//set ^zjb("ConsDual",5)="resp "_resp
			set tCodERP = tARCIMCode
			set tSC = ##class(Custom.ERP.StockWSHandler).GetStockOMNI(tOMNIArea, "", tCodERP, "", .pResponse)
			//set ^zjb("ConsDual","5.1")="resp "_tSC
			//Quit:$System.Status.IsError(tSC)
			
			if $get(pResponse)'=""
			{
				for tItemNum = 1:1:pResponse.Items.Count()
				{
					set tCantidadOMN = pResponse.Items.GetAt(tItemNum).Quantity
				}
			}	
		}
		
		if tIntegrationOn
		{
			//set ^zjb("ConsDual",6)="resp "_resp
			//Codigo Item
			set tCodERP = ..GetItemCodeERP(tINCIId)
			set tDescERP = pItemDescription
			set tSC = ##class(Custom.ERP.StockWSHandler).GetStockERP(tERPLoc, tCodERP, tDescERP, .pResponse)
			
			if $get(pResponse)'=""
			{
				for tItemNum = 1:1:pResponse.Items.Count()
				{
					set tCantidadERP = pResponse.Items.GetAt(tItemNum).Quantity
				}
			}
		}
		
		if $IsvalidNum(tCantidadERP) set tCantidadERP=$fnumber(tCantidadERP,".")
		if $IsvalidNum(tCantidadOMN) set tCantidadOMN=$fnumber(tCantidadOMN,".")
		set resp = "1^"_tCantidadERP_"^"_tCantidadOMN
		
		//set ^zjb("ConsDual",9)="resp "_resp
	}
	Catch (tException)
	{
		If tException.Name="<ZSOAP>"
		{
			Set tSC = %objlasterror
			Set resp= "0^"_$System.Status.GetErrorText(tSC)
		}
		Else
		{
			set ^zjb("ConsDual",10)="10 "_tSC
			Set tSC = tException.AsStatus()
			Set resp= "0^"_$System.Status.GetErrorText(tSC)
			set ^zjb("ConsDual",11)="11 "_tSC
		}
	}
	Quit resp
}

}
