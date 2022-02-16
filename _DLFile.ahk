; ===================================================================================
; Example
; ===================================================================================

url:="https://dl.google.com/android/repository/commandlinetools-win-8092744_latest.zip"
dest := A_Desktop "\commandlinetools-win-8092744_latest.zip"

DL := DLFile(url,dest,callback)
DL.del_on_cancel := true

g := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox","Download Progress")
g.OnEvent("close",(*)=>ExitApp())
g.OnEvent("escape",(*)=>ExitApp())
g.SetFont(,"Consolas")
g.Add("Text","w300 vText1 -Wrap")
g.Add("Progress","w300 vProg")
g.Add("Text","w300 vText2 -Wrap")
g.Add("Button","x255 w75 vCancel","Cancel").OnEvent("click",events)
g.Show()

DL.Start()

events(ctl,info) {
    If (ctl.name = "Cancel") {
        DL.cancel := true
        g["Text2"].Text := "Download Cancelled! / Percent: " DL.perc "% / Exit = ESC"
    }
}

callback(o:="") {
    g["Text1"].Text := o.file
    g["Text2"].Text := Round(o.bps/1024) " KBps   /   Percent: " o.perc "%"
    g["Prog"].Value := o.perc
}

If DL.perc = 100
    g["Text2"].Text := "Download Complete!  Press ESC to exit."

; ===================================================================================
; USAGE:
;
;   DLFile(url, dest, callback := "")
;
;   Params:
;
;   - url / dest = self explanitory
;
;   - callback = a func object
;
;       The callback func must accept a single param.  The param is an object with
;       the following properties:
;
;       - size  = total file size
;       - bytes = bytes downloaded so far
;       - bps   = the avg bytes per second
;       - file  = the file name
;       - perc  = percent complete
;       - url   = the full url
;       - dest  = specified destination dir/file
;       - cb    = the callback function object
;
;   Object properties:
;
;       - obj.del_on_cancel = set this to true to clean up a partial download after abort
;
;       - obj.cancel = set this to true to interrupt the download
;
;   Object methods:
;
;       - obj.Start() = Starts the download.  You can set del_on_cancel before
;                       starting the download.
;
;   WARNING:
;
;       Do not destroy the object during a download.  If you do, the handles will
;       likely not be able to be closed properly.  To gracefully terminate a
;       download, you must set:
;
;           obj.cancel := true
;
;       It is highly suggested to not use any other methods defined in this class
;       directly, unless you are doing something advanced, in which case proceed
;       with caution, and avoid buffer overrun errors.
; ===================================================================================

class DLFile {
    cancel := false, del_on_cancel := false
    size := 0, perc := 0, bytes := 0, bps := 0, file := 0
    
    __New(url, dest, cb:="") => (this.url := url, this.dest := dest, this.cb := cb)
    
    Start() {
        cb := this.cb
        this._SplitUrl(this.url,&protocol,&server,&port,&_dir_file,&_file)
        this.file := _file
        
        this.hSession := this.Open()
        this.hConnect := this.Connect(this.hSession, server, port)
        this.hRequest := this.OpenRequest(this.hConnect,"GET",_dir_file)
        
        this.SendRequest(this.hRequest)
        this.ReceiveResponse(this.hRequest)
        
        this.size := this.QueryHeaders(this.hRequest,"content-length")
        file_buf := FileOpen(this.dest ".temp","rw")
        lastBytes := 0, bps_arr := []
        SetTimer timer, 250
        
        While(d_size := this.QueryDataSize(this.hRequest)) {
            If (this.cancel)
                Break
            file_buf.RawWrite(this.ReadData(this.hRequest,d_size))
            this.bytes += d_size
        }
        SetTimer timer, 0
        If HasMethod(cb)
        && !this.cancel             ; ensure finished stats on completion
            this.bytes:=this.size, this.bps:=0, this.perc:=100
        
        file_buf.Close()
        If !this.cancel             ; remove ".temp" on complete
            FileMove(this.dest ".temp",this.dest)
        Else If this.del_on_cancel  ; delete partial download if enabled
            FileDelete(this.dest ".temp")
        this.Abort()                ; cleanup handles
        
        timer() {
            If HasMethod(cb) {
                bps_arr.Push(this.bytes - lastBytes)
                this.bps := this._get_avg(bps_arr)
                this.perc := Round(this.bytes/this.size*100)
                lastBytes := this.bytes
                cb(this)
            }
        }
    }
    
    _get_avg(bps_arr, result:=0) {
        For i, val in bps_arr
            result += val
        return Round(result / bps_arr.Length * 4)
    }
    
    _SplitUrl(url,&protocol,&server,&port,&_dir_file,&_file) {
        protocol := RegExReplace(url,"^(https|http).+","$1")
        s_p := StrSplit(RegExReplace(url,"^https?://([^/]+).+","$1"),":")
        server := s_p[1]
        port := (!s_p.Has(2)?0:Integer(s_p[2]))
        _dir_file := RegExReplace(url,"^\Q" protocol "://" server "\E","")
        _file := RegExReplace(url,".+?/([^/]+)$","$1")
    }
    
    _define_headers() { ; this can probably be trimmed
        headers := Map()
        headers.CaseSense := false
        headers.Set("mime-version",0,"content-type",1,"content-transfer-encoding",2,"content-id",3,"content-description",4,"content-length",5
            ,"content-language",6,"allow",7,"public",8,"date",9,"expires",10,"last-modified",11,"message-id",12,"uri",13,"derived-from",14,"cost",15
            ,"link",16,"pragma",17,"version",18,"status-code",19,"status-text",20,"raw-headers",21,"raw-headers-crlf",22,"connection",23,"accept",24
            ,"accept-charset",25,"accept-encoding",26,"accept-language",27,"authorization",28,"content-encoding",29,"forwarded",30,"from",31
            ,"if-modified-since",32,"location",33,"orig-uri",34,"referer",35,"retry-after",36,"server",37,"title",38,"user-agent",39
            ,"www-authenticate",40,"proxy-authenticate",41,"accept-ranges",42,"set-cookie",43,"cookie",44,"request-method",45,"refresh",46
            ,"content-disposition",47
            ; HTTP 1.1 headers
            ,"age",48,"cache-control",49,"content-base",50,"content-location",51,"content-md5",52,"content-range",53,"etag",54,"host",55,"if-match",56
            ,"if-none-match",57,"if-range",58,"if-unmodified-since",59,"max-forwards",60,"proxy-authorization",61,"range",62,"transfer-encoding",63
            ,"upgrade",64,"vary",65,"via",66,"warning",67,"expect",68,"proxy-connection",69,"unless-modified-since",70
            ,"proxy-support",75,"authentication-info",76,"passport-urls",77,"passport-config",78,"max",78
            ,"custom",65535)
        return headers
    }
    
    callback(hInternet, context, status, ptr, size) { ; currently not used
        If (status = 0x20) { ; request sent
            
        } Else if (status = 0x40) { ; receiving response
        
        } Else If (status = 0x80) { ; response received
            bytesRec := NumGet(ptr,"UInt")        
        } Else If (status = 0x400000) { ; send request complete
            
        } Else If (status = 0x10000) { ; check for error flags ; this.cb_stat_flags
        
        } Else if (status = 0x20000) { ; headers available
            
        } Else If (status = 0x40000) { ; data available
            size := NumGet(ptr,"UInt")
            
        } Else If (status = 0x80000) { ; read complete
            bytesRead := NumGet(ptr,"UInt")
        }
    }
    
    __Delete() => ((this.hRequest) ? this.Abort() : "")
    
    ; ==============================================================================
    ; prxType := 1          ; WINHTTP_ACCESS_TYPE_NO_PROXY
    ; dwFlags (DWORD)
    ;
    ; WINHTTP_FLAG_ASYNC              0x10000000  // this session is asynchronous (where supported)
    ; WINHTTP_FLAG_SECURE_DEFAULTS    0x30000000  // note that this flag also forces async
    Open(userAgent:="WinHTTP/5.0", prxType:=1, prxName:=0, prxBypass:=0, dwFlags:=0)
    => DllCall("Winhttp\WinHttpOpen","Str",userAgent,"UInt",prxType,(!prxName?"UPtr":"Str"),prxName
                                    ,(!prxBypass?"UPtr":"Str"),prxBypass,"UInt",dwFlags)
    
    ; ==============================================================================
    ; dwFlags := 0xFFFFFFFF ; all notifications
    SetCallback(hSession, pCallback, dwFlags)
    => DllCall("Winhttp\WinHttpSetStatusCallback","UPtr",hSession,"UPtr",pCallback,"UInt",dwFlags,"UPtr",0)
    
    ; ==============================================================================
    ; verb (string)
    ; _file (string)
    ; ref = referrer (string)
    ; dwFlags (DWORD) - combine values below
    ;
    ; WINHTTP_FLAG_SECURE                0x00800000  // use SSL if applicable (HTTPS)
    ; WINHTTP_FLAG_ESCAPE_PERCENT        0x00000004  // if escaping enabled, escape percent as well
    ; WINHTTP_FLAG_NULL_CODEPAGE         0x00000008  // assume all symbols are ASCII, use fast convertion
    ; WINHTTP_FLAG_BYPASS_PROXY_CACHE    0x00000100  // add "pragma: no-cache" request header
    ; WINHTTP_FLAG_REFRESH               WINHTTP_FLAG_BYPASS_PROXY_CACHE
    ; WINHTTP_FLAG_ESCAPE_DISABLE        0x00000040  // disable escaping
    ; WINHTTP_FLAG_ESCAPE_DISABLE_QUERY  0x00000080  // if escaping enabled escape path part, but do not escape query
    OpenRequest(hConnect, verb, _file:="/", ref:=0, media_types:="*/*", dwFlags:=0x00800000) {
        types_arr := StrSplit(media_types,":"," ")
        types_buf := Buffer(A_PtrSize*(types_arr.Length+1),0)
        For i, _type in types_arr
            NumPut("UPtr",StrPtr(_type),types_buf,(i-1)*A_PtrSize)
        
        return DllCall("Winhttp\WinHttpOpenRequest","UPtr",hConnect,"Str",verb,"Str",_file,"UPtr",0
                                      ,(!ref?"UPtr":"Str"),ref,"UPtr",types_buf.ptr,"UInt",dwFlags)
    }
    
    ; ==============================================================================
    Connect(hSession, server, port:=0)
    => this.hConnect := DllCall("Winhttp\WinHttpConnect","UPtr",hSession,"Str",server,"UInt",port,"UInt",0)
    
    ; ==============================================================================
    ; exH = extra headers (string)
    ; exD = extra data (buffer)
    ; ID  = context ID (user defined DWORD)
    SendRequest(hRequest, exH:=0, exD:=0, ID:=0)
    => DllCall("Winhttp\WinHttpSendRequest","UPtr",hRequest
                                           ,(!exH?"UPtr":"Str"),exH
                                           ,"UInt",(exH_sz:=(exH?StrPut(exH):0))
                                           ,"UPtr",(exD?exD.ptr:0)
                                           ,"UInt",(exD_sz:=(exD?exD.size:0))
                                           ,"UInt",exH_sz+exD_sz
                                           ,"UPtr",ID)
    
    ; ==============================================================================
    ReceiveResponse(hRequest) => DllCall("Winhttp\WinHttpReceiveResponse","UPtr",hRequest,"UPtr",0)
    
    ; ==============================================================================
    QueryHeaders(hRequest,headers:="") { ; this can probably be trimmed
        Static _headers_ := this._define_headers()
        hdr_list := _make_headers(), headers:=""
        
        For hdr, val in hdr_list {
            _iHdr := _headers_[hdr] ? _headers_[hdr] : _headers_["custom"]
            _hdr_typ := ((_iHdr=65535)?"Str":"UPtr")
            idx:=0, last_idx:=-1, size:=0
            
            While (last_idx!=idx) { ; ERROR_WINHTTP_HEADER_NOT_FOUND = 12150
                r := DllCall("Winhttp\WinHttpQueryHeaders","UPtr",hRequest,"UInt",_iHdr
                            ,_hdr_typ,((_iHdr=65535)?hdr:0),"UPtr",0,"UInt*",&size,"UPtr",0)
                
                If (size) {
                    buf := Buffer(size,0)
                    r := DllCall("Winhttp\WinHttpQueryHeaders","UPtr",hRequest,"UInt",_iHdr
                                ,_hdr_typ,((_iHdr=65535)?StrPtr(hdr):0),"UPtr",buf.ptr,"UInt*",buf.size,"UPtr",0)
                    return StrGet(buf)
                }
                
                last_idx := idx
            }
        }
        
        return headers
        
        _make_headers() {
            _hdr_list := Map(), _hdr_list.CaseSense := false
            If !headers
                _hdr_list["raw-headers-crlf"] := 22
            Else
                For i, hdr in StrSplit(headers,";"," ")
                    _hdr_list[hdr] := (_headers_.Has(hdr)) ? _headers_[hdr] : 65535
            return _hdr_list
        }
    }
    
    QueryDataSize(hRequest) {
        r := DllCall("Winhttp\WinHttpQueryDataAvailable","UPtr",hRequest,"UInt*",&chunk:=0)
        return chunk
    }
    
    ReadData(hRequest,size) {
        buf := Buffer(size,0)
        r := DllCall("Winhttp\WinHttpReadData","UPtr",hRequest,"UPtr",buf.ptr,"UInt",size,"UInt*",&bytesRead:=0)
        return buf
    }
    
    CloseHandle(handle) => DllCall("Winhttp\WinHttpCloseHandle","UPtr",handle)
    
    Abort() {
        If !(this.CloseHandle(this.hRequest))
            throw Error("Unable to close request handle.",-1)
        If !(this.CloseHandle(this.hConnect))
            throw Error("Unable to close connect handle.",-1)
        If !(this.CloseHandle(this.hSession))
            throw Error("Unable to close session handle.",-1)
        this.hRequest := this.hConnect := this.hSession := 0
    }
}



; dbg(_in) { ; AHK v2
    ; Loop Parse _in, "`n", "`r"
        ; OutputDebug "AHK: " A_LoopField
; }

