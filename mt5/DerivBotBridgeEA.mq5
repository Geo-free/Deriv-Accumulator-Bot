//+------------------------------------------------------------------+
//| Deriv Bot Pro MT5 Bridge EA                                      |
//| Polls a bot signal endpoint and places MT5 market orders.        |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"

#include <Trade/Trade.mqh>

input string InpSignalUrl = "https://deriv-accumulator-bot.vercel.app/api/mt5-signal";
input int    InpPollSeconds = 2;
input int    InpDeviationPoints = 20;
input long   InpMagic = 80689444;

CTrade trade;
string last_signal_id = "";

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   EventSetTimer(MathMax(1, InpPollSeconds));
   Print("Deriv Bot Bridge EA started. Allow WebRequest URL: ", InpSignalUrl);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTimer()
{
   string json = HttpGet(InpSignalUrl);
   if(json == "" || StringFind(json, "\"signal\":null") >= 0)
      return;

   string id = JsonString(json, "id");
   if(id == "" || id == last_signal_id)
      return;

   string action = JsonString(json, "action");
   string symbol = JsonString(json, "symbol");
   double lot = JsonNumber(json, "lot", 0.01);
   double sl_points = JsonNumber(json, "sl_points", 0);
   double tp_points = JsonNumber(json, "tp_points", 0);

   if(symbol == "" || (action != "buy" && action != "sell"))
   {
      Print("Invalid signal payload: ", json);
      return;
   }

   if(!SymbolSelect(symbol, true))
   {
      Print("Could not select symbol: ", symbol);
      return;
   }

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
   {
      Print("No tick for symbol: ", symbol);
      return;
   }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double price = action == "buy" ? tick.ask : tick.bid;
   double sl = 0;
   double tp = 0;

   if(action == "buy")
   {
      if(sl_points > 0) sl = NormalizeDouble(price - sl_points * point, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      if(tp_points > 0) tp = NormalizeDouble(price + tp_points * point, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   }
   else
   {
      if(sl_points > 0) sl = NormalizeDouble(price + sl_points * point, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      if(tp_points > 0) tp = NormalizeDouble(price - tp_points * point, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   }

   trade.SetDeviationInPoints(InpDeviationPoints);
   bool ok = action == "buy"
      ? trade.Buy(lot, symbol, 0, sl, tp, id)
      : trade.Sell(lot, symbol, 0, sl, tp, id);

   if(ok)
   {
      last_signal_id = id;
      Print("Executed signal ", id, ": ", action, " ", symbol, " lot=", DoubleToString(lot, 2));
      AckSignal(id);
   }
   else
   {
      Print("Order failed for signal ", id, ". Retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
}

string HttpGet(string url)
{
   char data[];
   char result[];
   string result_headers;
   ResetLastError();
   int status = WebRequest("GET", url, "", 5000, data, result, result_headers);
   if(status != 200)
   {
      Print("Signal GET failed. HTTP=", status, " error=", GetLastError());
      return "";
   }
   return CharArrayToString(result, 0, ArraySize(result), CP_UTF8);
}

void AckSignal(string id)
{
   string payload = "{\"executed_id\":\"" + id + "\"}";
   char data[];
   char result[];
   string result_headers;
   StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);
   WebRequest("POST", InpSignalUrl, "Content-Type: application/json\r\n", 5000, data, result, result_headers);
}

string JsonString(string json, string key)
{
   string marker = "\"" + key + "\":";
   int pos = StringFind(json, marker);
   if(pos < 0) return "";
   pos += StringLen(marker);
   while(pos < StringLen(json) && StringGetCharacter(json, pos) == ' ') pos++;
   if(pos >= StringLen(json) || StringGetCharacter(json, pos) != '"') return "";
   pos++;
   int end = StringFind(json, "\"", pos);
   if(end < 0) return "";
   return StringSubstr(json, pos, end - pos);
}

double JsonNumber(string json, string key, double fallback)
{
   string marker = "\"" + key + "\":";
   int pos = StringFind(json, marker);
   if(pos < 0) return fallback;
   pos += StringLen(marker);
   while(pos < StringLen(json) && StringGetCharacter(json, pos) == ' ') pos++;
   int end = pos;
   while(end < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, end);
      if((ch >= '0' && ch <= '9') || ch == '.' || ch == '-') end++;
      else break;
   }
   if(end <= pos) return fallback;
   return StringToDouble(StringSubstr(json, pos, end - pos));
}
