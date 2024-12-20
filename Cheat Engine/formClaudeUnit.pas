unit formClaudeUnit;

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Menus, LCLType, CEFuncProc, NewKernelHandler, MemoryRecordUnit,
  commonTypeDefs, betterControls, AnthropicAPI;

type
  TFormClaude = class(TForm)
    memoChat: TMemo;
    memoInput: TMemo;
    btnSend: TButton;
    pnlTop: TPanel;
    lblStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FAnthropicKey: string;
    FAnthropicClient: TAnthropicClient;
    procedure SendToClaude(const Message: string);
    procedure HandleClaudeResponse(const Response: string);
    function GetMemoryValue(const Address: string; Size: integer): string;
    procedure ExecuteLuaScript(const Script: string);
    function GetCurrentContext: string;
    procedure PerformMemoryScan(const ScanType, ValueType, Value: string);
    function GenerateAOBSignature(const Address: string; Size: integer): string;
    procedure AddMemoryRecord(const Address, Description: string; VarType: TVariableType);
    function AnalyzePointerPath(const Address: string): string;
  public
    property AnthropicKey: string read FAnthropicKey write FAnthropicKey;
  end;

var
  FormClaude: TFormClaude;

implementation

{$R *.lfm}

uses
  MainUnit, ProcessHandlerUnit, LuaHandler;

procedure TFormClaude.FormCreate(Sender: TObject);
begin
  memoChat.Clear;
  memoInput.Clear;
  lblStatus.Caption := 'Ready';
  
  // Initialize API client if key exists
  if FAnthropicKey <> '' then
    FAnthropicClient := TAnthropicClient.Create(FAnthropicKey);
end;

procedure TFormClaude.btnSendClick(Sender: TObject);
begin
  if memoInput.Text <> '' then
  begin
    memoChat.Lines.Add('You: ' + memoInput.Text);
    SendToClaude(memoInput.Text);
    memoInput.Clear;
  end;
end;

function TFormClaude.GetCurrentContext: string;
var
  i: integer;
  mr: TMemoryRecord;
begin
  Result := 'Current Process: ' + ProcessHandler.ProcessName + ' (PID: ' + IntToStr(ProcessHandler.ProcessID) + ')' + #13#10;
  
  // Add scan info if available
  if Assigned(MainForm.memscan) then
  begin
    Result := Result + 'Last Scan Type: ' + MainForm.scantype.Text + #13#10;
    Result := Result + 'Variable Type: ' + MainForm.vartype.Text + #13#10;
    if MainForm.foundcount > 0 then
      Result := Result + 'Found Values: ' + IntToStr(MainForm.foundcount) + #13#10;
  end;

  // Add active memory records
  if MainForm.addresslist.Count > 0 then
  begin
    Result := Result + #13#10 + 'Active Memory Records:' + #13#10;
    for i := 0 to min(5, MainForm.addresslist.Count - 1) do
    begin
      mr := MainForm.addresslist[i];
      Result := Result + Format('- %s: %s (%s) at %s', [
        mr.Description,
        mr.Value,
        mr.GetTypeName,
        mr.GetAddressString
      ]) + #13#10;
    end;
    if MainForm.addresslist.Count > 5 then
      Result := Result + '... and ' + IntToStr(MainForm.addresslist.Count - 5) + ' more' + #13#10;
  end;
end;

procedure TFormClaude.SendToClaude(const Message: string);
var
  Response: string;
  EnhancedPrompt: string;
  Context: string;
begin
  if not Assigned(FAnthropicClient) then
  begin
    if FAnthropicKey = '' then
    begin
      HandleClaudeResponse('Please set your Anthropic API key in the settings.');
      Exit;
    end;
    FAnthropicClient := TAnthropicClient.Create(FAnthropicKey);
  end;

  lblStatus.Caption := 'Sending...';
  Application.ProcessMessages;

  try
    Context := GetCurrentContext;
    
    EnhancedPrompt :=
      'You are Claude, an AI assistant integrated into Cheat Engine specialized in game cheat development. Your capabilities include:'#13#10 +
      #13#10 +
      'MEMORY ANALYSIS:'#13#10 +
      '- Reading and interpreting memory values'#13#10 +
      '- Identifying common value types (health, ammo, coordinates)'#13#10 +
      '- Understanding memory patterns and structures'#13#10 +
      '- Analyzing pointer chains and static addresses'#13#10 +
      #13#10 +
      'SCANNING STRATEGIES:'#13#10 +
      '- First scan techniques (exact value, unknown initial)'#13#10 +
      '- Next scan approaches (increased, decreased)'#13#10 +
      '- Value type selection (4 bytes, float, double)'#13#10 +
      '- Filtering and narrowing results'#13#10 +
      #13#10 +
      'CHEAT DEVELOPMENT:'#13#10 +
      '- Creating reliable pointer paths'#13#10 +
      '- Generating AOB signatures for version independence'#13#10 +
      '- Writing auto-assembler scripts'#13#10 +
      '- Building reusable cheat tables'#13#10 +
      #13#10 +
      'GAME MECHANICS:'#13#10 +
      '- Common game value locations'#13#10 +
      '- Typical memory structure patterns'#13#10 +
      '- Anti-cheat awareness and bypassing'#13#10 +
      '- Game engine specific knowledge'#13#10 +
      #13#10 +
      'Current Context:'#13#10 +
      Context + #13#10 +
      #13#10 +
      'Available Functions:'#13#10 +
      '1. GetMemoryValue(address, size) - Read raw memory values'#13#10 +
      '2. ExecuteLuaScript(script) - Run Lua code for advanced operations'#13#10 +
      '3. PerformMemoryScan(scanType, valueType, value) - Initiate memory scans'#13#10 +
      '4. GenerateAOBSignature(address, size) - Create unique byte patterns'#13#10 +
      '5. AddMemoryRecord(address, description, varType) - Add to cheat table'#13#10 +
      '6. AnalyzePointerPath(address) - Trace pointer chains'#13#10 +
      #13#10 +
      'Workflow Steps:'#13#10 +
      '1. Identify target value in game'#13#10 +
      '2. Perform initial scan'#13#10 +
      '3. Narrow results with next scans'#13#10 +
      '4. Analyze found addresses'#13#10 +
      '5. Create stable pointer or AOB'#13#10 +
      '6. Generate cheat table entry'#13#10 +
      #13#10 +
      'User Request: ' + Message;

    Response := FAnthropicClient.SendMessage(EnhancedPrompt);
    HandleClaudeResponse(Response);
  except
    on E: Exception do
      HandleClaudeResponse('Error: ' + E.Message);
  end;

  lblStatus.Caption := 'Ready';
end;

procedure TFormClaude.HandleClaudeResponse(const Response: string);
var
  LowerResponse: string;
  CommandStart, CommandEnd: Integer;
  Command, Params: string;
begin
  memoChat.Lines.Add('Claude: ' + Response);
  
  // Look for commands in [command:params] format
  LowerResponse := LowerCase(Response);
  CommandStart := Pos('[', LowerResponse);
  
  while CommandStart > 0 do
  begin
    CommandEnd := Pos(']', LowerResponse, CommandStart);
    if CommandEnd > 0 then
    begin
      // Extract command and parameters
      Command := Copy(Response, CommandStart + 1, CommandEnd - CommandStart - 1);
      
      // Split command and params
      Params := '';
      if Pos(':', Command) > 0 then
      begin
        Params := Copy(Command, Pos(':', Command) + 1, Length(Command));
        Command := Copy(Command, 1, Pos(':', Command) - 1);
        Command := LowerCase(Trim(Command));
        Params := Trim(Params);
      end;
      
      // Execute command
      try
        case Command of
          'scan' : begin
            if Pos(',', Params) > 0 then
            begin
              var ScanType := Copy(Params, 1, Pos(',', Params) - 1);
              var Rest := Copy(Params, Pos(',', Params) + 1, Length(Params));
              var ValueType := Copy(Rest, 1, Pos(',', Rest) - 1);
              var Value := Copy(Rest, Pos(',', Rest) + 1, Length(Rest));
              PerformMemoryScan(Trim(ScanType), Trim(ValueType), Trim(Value));
            end;
          end;
          
          'read' : begin
            if Pos(',', Params) > 0 then
            begin
              var Address := Copy(Params, 1, Pos(',', Params) - 1);
              var Size := StrToIntDef(Copy(Params, Pos(',', Params) + 1, Length(Params)), 4);
              memoChat.Lines.Add(GetMemoryValue(Trim(Address), Size));
            end;
          end;
          
          'aob' : begin
            if Pos(',', Params) > 0 then
            begin
              var Address := Copy(Params, 1, Pos(',', Params) - 1);
              var Size := StrToIntDef(Copy(Params, Pos(',', Params) + 1, Length(Params)), 8);
              GenerateAOBSignature(Trim(Address), Size);
            end;
          end;
          
          'pointer' : begin
            memoChat.Lines.Add(AnalyzePointerPath(Trim(Params)));
          end;
          
          'lua' : begin
            ExecuteLuaScript(Params);
          end;
          
          'addrecord' : begin
            if Pos(',', Params) > 0 then
            begin
              var Address := Copy(Params, 1, Pos(',', Params) - 1);
              var Rest := Copy(Params, Pos(',', Params) + 1, Length(Params));
              var Description := Copy(Rest, 1, Pos(',', Rest) - 1);
              var VarType := Copy(Rest, Pos(',', Rest) + 1, Length(Rest));
              AddMemoryRecord(
                Trim(Address),
                Trim(Description),
                TVariableType(GetEnumValue(TypeInfo(TVariableType), 'vt' + Trim(VarType)))
              );
            end;
          end;
        end;
      except
        on E: Exception do
          memoChat.Lines.Add('Error executing command: ' + E.Message);
      end;
    end;
    
    // Look for next command
    CommandStart := Pos('[', LowerResponse, CommandEnd);
  end;
end;

function TFormClaude.GetMemoryValue(const Address: string; Size: integer): string;
var
  buf: array of byte;
  addr: ptruint;
begin
  Result := '';
  try
    addr := StrToQWord('$' + Address);
    SetLength(buf, Size);
    if ReadProcessMemory(ProcessHandler.ProcessHandle, pointer(addr), @buf[0], Size, nil) then
    begin
      Result := Format('Value at %s: ', [Address]);
      for var i := 0 to Size-1 do
        Result := Result + IntToHex(buf[i], 2) + ' ';
    end;
  except
    Result := 'Error reading memory';
  end;
end;

procedure TFormClaude.ExecuteLuaScript(const Script: string);
begin
  try
    LuaCS.ExecuteScript(Script);
  except
    on E: Exception do
      memoChat.Lines.Add('Error executing script: ' + E.Message);
  end;
end;

procedure TFormClaude.PerformMemoryScan(const ScanType, ValueType, Value: string);
begin
  try
    // Set scan type
    MainForm.scantype.Text := ScanType;
    MainForm.vartype.Text := ValueType;
    MainForm.scanvalue.Text := Value;
    
    // Perform the scan
    if MainForm.btnNextScan.Enabled then
      MainForm.btnNextScan.Click
    else
      MainForm.btnNewScan.Click;
      
    memoChat.Lines.Add('Scan completed. Found: ' + IntToStr(MainForm.foundcount));
  except
    on E: Exception do
      memoChat.Lines.Add('Error performing scan: ' + E.Message);
  end;
end;

function TFormClaude.GenerateAOBSignature(const Address: string; Size: integer): string;
var
  buf: array of byte;
  addr: ptruint;
  i: integer;
begin
  Result := '';
  try
    addr := StrToQWord('$' + Address);
    SetLength(buf, Size);
    if ReadProcessMemory(ProcessHandler.ProcessHandle, pointer(addr), @buf[0], Size, nil) then
    begin
      // Generate AOB pattern
      for i := 0 to Size-1 do
        Result := Result + IntToHex(buf[i], 2) + ' ';
        
      memoChat.Lines.Add('Generated AOB signature: ' + Result);
    end;
  except
    on E: Exception do
    begin
      Result := '';
      memoChat.Lines.Add('Error generating AOB signature: ' + E.Message);
    end;
  end;
end;

procedure TFormClaude.AddMemoryRecord(const Address, Description: string; VarType: TVariableType);
var
  mr: TMemoryRecord;
begin
  try
    mr := MainForm.addresslist.addAddressManually(Address);
    if mr <> nil then
    begin
      mr.Description := Description;
      mr.VarType := VarType;
      memoChat.Lines.Add('Added memory record: ' + Description + ' at ' + Address);
    end;
  except
    on E: Exception do
      memoChat.Lines.Add('Error adding memory record: ' + E.Message);
  end;
end;

function TFormClaude.AnalyzePointerPath(const Address: string): string;
var
  addr: ptruint;
  value: ptruint;
  level: integer;
  path: string;
begin
  Result := '';
  try
    addr := StrToQWord('$' + Address);
    path := 'Base: ' + IntToHex(addr, 8);
    level := 0;
    
    // Follow pointer path up to 5 levels deep
    while (level < 5) and (addr <> 0) do
    begin
      if ReadProcessMemory(ProcessHandler.ProcessHandle, pointer(addr), @value, SizeOf(value), nil) then
      begin
        path := path + #13#10 + 'Level ' + IntToStr(level) + ': ' + IntToHex(value, 8);
        addr := value;
        Inc(level);
      end
      else
        break;
    end;
    
    Result := path;
    memoChat.Lines.Add('Pointer analysis:'#13#10 + Result);
  except
    on E: Exception do
    begin
      Result := 'Error analyzing pointer path: ' + E.Message;
      memoChat.Lines.Add(Result);
    end;
  end;
end;

procedure TFormClaude.FormDestroy(Sender: TObject);
begin
  if Assigned(FAnthropicClient) then
    FAnthropicClient.Free;
end;

end.
