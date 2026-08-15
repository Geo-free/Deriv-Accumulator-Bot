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
   ReportPositions();

   string json = HttpGet(InpSignalUrl);
   if(json == "" || StringFind(json, "\"signal\":null") >= 0)
      return;

   string id = JsonString(json, "id");
   if(id == "" || id == last_signal_id)
      return;

   string action = JsonString(json, "action");
   string symbol = JsonString(json, "symbol");
   ulong ticket = (ulong)JsonNumber(json, "ticket", 0);
   double lot = JsonNumber(json, "lot", 0.01);
   double sl_points = JsonNumber(json, "sl_points", 0);
   double tp_points = JsonNumber(json, "tp_points", 0);

   if(action == "close")
   {
      ClosePositionCommand(id, ticket);
      return;
   }

   if(action == "modify")
   {
      ModifyPositionCommand(id, ticket, JsonNumber(json, "sl", -1), JsonNumber(json, "tp", -1));
      return;
   }

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

void ClosePositionCommand(string id, ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
   {
      Print("Close failed. Position not found: ", ticket);
      return;
   }
   string symbol = PositionGetString(POSITION_SYMBOL);
   if(trade.PositionClose(symbol))
   {
      last_signal_id = id;
      Print("Closed MT5 position ", ticket, " on ", symbol);
      AckSignal(id);
   }
   else
   {
      Print("Close failed for ", ticket, ". Retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
}

void ModifyPositionCommand(string id, ulong ticket, double sl, double tp)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
   {
      Print("Modify failed. Position not found: ", ticket);
      return;
   }
   string symbol = PositionGetString(POSITION_SYMBOL);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double next_sl = sl >= 0 ? sl : current_sl;
   double next_tp = tp >= 0 ? tp : current_tp;
   if(trade.PositionModify(symbol, next_sl, next_tp))
   {
      last_signal_id = id;
      Print("Modified MT5 position ", ticket, " SL=", DoubleToString(next_sl, _Digits), " TP=", DoubleToString(next_tp, _Digits));
      AckSignal(id);
   }
   else
   {
      Print("Modify failed for ", ticket, ". Retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
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

void ReportPositions()
{
   string payload = "{\"positions\":[";
   int added = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(added > 0) payload += ",";
      string symbol = PositionGetString(POSITION_SYMBOL);
      long type = PositionGetInteger(POSITION_TYPE);
      string side = type == POSITION_TYPE_BUY ? "buy" : "sell";
      payload += "{";
      payload += "\"ticket\":\"" + IntegerToString((long)ticket) + "\",";
      payload += "\"symbol\":\"" + symbol + "\",";
      payload += "\"type\":\"" + side + "\",";
      payload += "\"volume\":" + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) + ",";
      payload += "\"price_open\":" + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + ",";
      payload += "\"profit\":" + DoubleToString(PositionGetDouble(POSITION_PROFIT), 2) + ",";
      payload += "\"sl\":" + DoubleToString(PositionGetDouble(POSITION_SL), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + ",";
      payload += "\"tp\":" + DoubleToString(PositionGetDouble(POSITION_TP), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      payload += "}";
      added++;
   }
   payload += "]}";

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
