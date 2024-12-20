unit AnthropicAPI;

interface

uses
  Classes, SysUtils, fpjson, jsonparser, fphttpclient, opensslsockets, base64,
  dialogs;

type
  TAnthropicClient = class
  private
    FApiKey: string;
    FModel: string;
    FMaxTokens: Integer;
    FTemperature: Double;
    function BuildRequestBody(const Prompt: string): string;
    function ParseResponse(const Response: string): string;
  public
    constructor Create(const ApiKey: string);
    function SendMessage(const Message: string): string;
    property Model: string read FModel write FModel;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property Temperature: Double read FTemperature write FTemperature;
  end;

implementation

constructor TAnthropicClient.Create(const ApiKey: string);
begin
  inherited Create;
  FApiKey := ApiKey;
  FModel := 'claude-3-opus-20240229';
  FMaxTokens := 1024;
  FTemperature := 0.7;
end;

function TAnthropicClient.BuildRequestBody(const Prompt: string): string;
var
  Json: TJSONObject;
  MessagesArray: TJSONArray;
  MessageObj: TJSONObject;
begin
  Result := '';
  Json := TJSONObject.Create;
  try
    Json.Add('model', FModel);
    Json.Add('max_tokens', FMaxTokens);
    Json.Add('temperature', FTemperature);
    
    MessagesArray := TJSONArray.Create;
    MessageObj := TJSONObject.Create;
    MessageObj.Add('role', 'user');
    MessageObj.Add('content', Prompt);
    MessagesArray.Add(MessageObj); // MessageObj is now owned by MessagesArray
    Json.Add('messages', MessagesArray); // MessagesArray is now owned by Json
    
    Result := Json.AsJSON;
  finally
    Json.Free; // This will free MessagesArray and MessageObj
  end;
end;

function TAnthropicClient.ParseResponse(const Response: string): string;
var
  Json: TJSONObject;
  Content: TJSONData;
begin
  Result := '';
  try
    Json := TJSONObject(GetJSON(Response));
    try
      Content := Json.FindPath('content[0].text');
      if Assigned(Content) then
        Result := Content.AsString;
    finally
      Json.Free;
    end;
  except
    on E: Exception do
      Result := 'Error parsing response: ' + E.Message;
  end;
end;

function TAnthropicClient.SendMessage(const Message: string): string;
var
  Http: TFPHTTPClient;
  RequestBody: string;
  Response: string;
begin
  Result := '';
  Http := TFPHTTPClient.Create(nil);
  try
    Http.AddHeader('Content-Type', 'application/json');
    Http.AddHeader('x-api-key', FApiKey);
    Http.AddHeader('anthropic-version', '2023-06-01');
    
    RequestBody := BuildRequestBody(Message);
    
    try
      Response := Http.SimplePost(
        'https://api.anthropic.com/v1/messages',
        RequestBody
      );
      Result := ParseResponse(Response);
    except
      on E: Exception do
        Result := 'Error sending message: ' + E.Message;
    end;
  finally
    Http.Free;
  end;
end;

end.
