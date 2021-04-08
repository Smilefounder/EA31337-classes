//+------------------------------------------------------------------+
//|                                                EA31337 framework |
//|                       Copyright 2016-2021, 31337 Investments Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

/*
 * This file is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

/**
 * @file
 * Includes Trade's structs.
 */

// Forward declarations.
struct TradeStats;

// Includes.
#include "DateTime.mqh"
#include "Trade.enum.h"

/* Structure for trade parameters. */
struct TradeParams {
  float lot_size;     // Default lot size.
  float risk_margin;  // Maximum account margin to risk (in %).
  // Classes.
  Account *account;        // Pointer to Account class.
  Chart *chart;            // Pointer to Chart class.
  Ref<Log> logger;         // Reference to Log object.
  Ref<Terminal> terminal;  // Reference to Terminal object.
  unsigned int limits_stats[FINAL_ENUM_TRADE_STAT_TYPE][FINAL_ENUM_TRADE_STAT_PERIOD];
  unsigned int slippage;    // Value of the maximum price slippage in points.
  unsigned short bars_min;  // Minimum bars to trade.
  // Market          *market;     // Pointer to Market class.
  // void Init(TradeParams &p) { slippage = p.slippage; account = p.account; chart = p.chart; }
  // Constructors.
  TradeParams() : bars_min(100) { SetLimits(0); }
  TradeParams(Account *_account, Chart *_chart, Log *_log, float _lot_size = 0, float _risk_margin = 1.0,
              unsigned int _slippage = 50)
      : account(_account),
        bars_min(100),
        chart(_chart),
        logger(_log),
        lot_size(_lot_size),
        risk_margin(_risk_margin),
        slippage(_slippage) {
    terminal = new Terminal();
    SetLimits(0);
  }
  // Deconstructor.
  ~TradeParams() {}
  // Getters.
  float GetRiskMargin() { return risk_margin; }
  unsigned int GetLimits(ENUM_TRADE_STAT_TYPE _type, ENUM_TRADE_STAT_PERIOD _period) {
    return limits_stats[_type][_period];
  }
  unsigned short GetBarsMin() { return bars_min; }
  // State checkers.
  bool IsLimitGe(ENUM_TRADE_STAT_TYPE _type, unsigned int &_value[]) {
    // Is limit greater or equal than given value for given array of types.
    for (ENUM_TRADE_STAT_PERIOD p = 0; p < FINAL_ENUM_TRADE_STAT_PERIOD; p++) {
      if (_value[p] > 0 && IsLimitGe(_type, p, _value[p])) {
        return true;
      }
    }
    return false;
  }
  bool IsLimitGe(ENUM_TRADE_STAT_TYPE _type, ENUM_TRADE_STAT_PERIOD _period, unsigned int _value) {
    // Is limit greater or equal than given value for given type and period.
    return limits_stats[_type][_period] > 0 && _value >= limits_stats[_type][_period];
  }
  bool IsLimitGe(TradeStats &_stats) {
    for (ENUM_TRADE_STAT_TYPE t = 0; t < FINAL_ENUM_TRADE_STAT_TYPE; t++) {
      for (ENUM_TRADE_STAT_PERIOD p = 0; p < FINAL_ENUM_TRADE_STAT_PERIOD; p++) {
        if (_stats.order_stats[t][p] > 0 && IsLimitGe(t, p, _stats.order_stats[t][p])) {
          return true;
        }
      }
    }
    return false;
  }
  // Setters.
  void SetBarsMin(unsigned short _value) { bars_min = _value; }
  void SetLimits(ENUM_TRADE_STAT_TYPE _type, ENUM_TRADE_STAT_PERIOD _period, uint _value = 0) {
    // Set new trading limits for the given type and period.
    limits_stats[_type][_period] = _value;
  }
  void SetLimits(ENUM_TRADE_STAT_PERIOD _period, uint _value = 0) {
    // Set new trading limits for the given period.
    for (int t = 0; t < FINAL_ENUM_TRADE_STAT_TYPE; t++) {
      limits_stats[t][_period] = _value;
    }
  }
  void SetLimits(ENUM_TRADE_STAT_TYPE _type, uint _value = 0) {
    // Set new trading limits for the given type.
    for (ENUM_TRADE_STAT_PERIOD p = 0; p < FINAL_ENUM_TRADE_STAT_PERIOD; p++) {
      limits_stats[_type][p] = _value;
    }
  }
  void SetLimits(uint _value = 0) {
    // Set new trading limits for all types and periods.
    // Zero value is for no limits.
    for (ENUM_TRADE_STAT_TYPE t = 0; t < FINAL_ENUM_TRADE_STAT_TYPE; t++) {
      for (ENUM_TRADE_STAT_PERIOD p = 0; p < FINAL_ENUM_TRADE_STAT_PERIOD; p++) {
        limits_stats[t][p] = _value;
      }
    }
  }
  void SetLotSize(float _lot_size) { lot_size = _lot_size; }
  void SetRiskMargin(float _value) { risk_margin = _value; }
  // Struct methods.
  void DeleteObjects() {
    Object::Delete(account);
    Object::Delete(chart);
  }
  // Serializers.
  void SerializeStub(int _n1 = 1, int _n2 = 1, int _n3 = 1, int _n4 = 1, int _n5 = 1) {}
  SerializerNodeType Serialize(Serializer &_s) {
    _s.Pass(this, "lot_size", lot_size);
    _s.Pass(this, "risk_margin", risk_margin);
    _s.Pass(this, "slippage", slippage);
    return SerializerNodeObject;
  }
};

/* Structure for trade statistics. */
struct TradeStats {
  DateTime dt;
  unsigned int order_stats[FINAL_ENUM_TRADE_STAT_TYPE][FINAL_ENUM_TRADE_STAT_PERIOD];
  // Struct constructors.
  TradeStats() { ResetStats(); }
  // Check statistics for new periods
  void Check() {}
  /* Getters */
  // Get order stats for the given type and period.
  unsigned int GetOrderStats(ENUM_TRADE_STAT_TYPE _type, ENUM_TRADE_STAT_PERIOD _period, bool _reset = true) {
    if (_reset && _period < TRADE_STAT_ALL) {
      unsigned short _periods_started = dt.GetStartedPeriods();
      if (_periods_started >= DATETIME_HOUR) {
        ResetStats(_periods_started);
      }
    }
    return order_stats[_type][_period];
  }
  /* Setters */
  // Add value for the given type and period.
  void Add(ENUM_TRADE_STAT_TYPE _type, int _value = 1) {
    for (int p = 0; p < FINAL_ENUM_TRADE_STAT_PERIOD; p++) {
      order_stats[_type][p] += _value;
    }
  }
  /* Reset stats for the given periods. */
  void ResetStats(unsigned short _periods) {
    if ((_periods & DATETIME_HOUR) != 0) {
      ResetStats(TRADE_STAT_PER_HOUR);
    }
    if ((_periods & DATETIME_DAY) != 0) {
      // New day started.
      ResetStats(TRADE_STAT_PER_DAY);
    }
    if ((_periods & DATETIME_WEEK) != 0) {
      ResetStats(TRADE_STAT_PER_WEEK);
    }
    if ((_periods & DATETIME_MONTH) != 0) {
      ResetStats(TRADE_STAT_PER_MONTH);
    }
    if ((_periods & DATETIME_YEAR) != 0) {
      ResetStats(TRADE_STAT_PER_YEAR);
    }
  }
  /* Reset stats for the given type and period. */
  void ResetStats(ENUM_TRADE_STAT_TYPE _type, ENUM_TRADE_STAT_PERIOD _period) { order_stats[_type][_period] = 0; }
  /* Reset stats for the given period. */
  void ResetStats(ENUM_TRADE_STAT_PERIOD _period) {
    for (int t = 0; t < FINAL_ENUM_TRADE_STAT_TYPE; t++) {
      order_stats[t][_period] = 0;
    }
  }
  /* Reset stats for the given type. */
  void ResetStats(ENUM_TRADE_STAT_TYPE _type) {
    for (int p = 0; p < FINAL_ENUM_TRADE_STAT_PERIOD; p++) {
      order_stats[_type][p] = 0;
    }
  }
  /* Reset all stats. */
  void ResetStats() {
    for (int t = 0; t < FINAL_ENUM_TRADE_STAT_TYPE; t++) {
      for (int p = 0; p < FINAL_ENUM_TRADE_STAT_PERIOD; p++) {
        order_stats[t][p] = 0;
      }
    }
  }
};

/* Structure for trade states. */
struct TradeStates {
  unsigned int states;
  // Struct constructor.
  TradeStates() : states(0) {}
  // Getters.
  static string GetStateMessage(ENUM_TRADE_STATE _state) {
    switch (_state) {
      case TRADE_STATE_BARS_NOT_ENOUGH:
        return "Not enough bars to trade";
      case TRADE_STATE_HEDGE_NOT_ALLOWED:
        return "Hedging not allowed by broker";
      case TRADE_STATE_MARGIN_MAX_HARD:
        return "Hard limit of trade margin reached";
      case TRADE_STATE_MARGIN_MAX_SOFT:
        return "Soft limit of trade margin reached";
      case TRADE_STATE_MARKET_CLOSED:
        return "Trade market closed";
      case TRADE_STATE_MONEY_NOT_ENOUGH:
        return "Not enough money to trade";
      case TRADE_STATE_ORDERS_ACTIVE:
        return "New orders has been placed";
      case TRADE_STATE_ORDERS_MAX_HARD:
        return "Soft limit of maximum orders reached";
      case TRADE_STATE_ORDERS_MAX_SOFT:
        return "Hard limit of maximum orders reached";
      case TRADE_STATE_PERIOD_LIMIT_REACHED:
        return "Per period limit reached";
      case TRADE_STATE_SPREAD_TOO_HIGH:
        return "Spread too high";
      case TRADE_STATE_TRADE_NOT_ALLOWED:
        return "Trade not allowed";
      case TRADE_STATE_TRADE_NOT_POSSIBLE:
        return "Trade not possible";
      case TRADE_STATE_TRADE_TERMINAL_BUSY:
        return "Terminal context busy";
      case TRADE_STATE_TRADE_TERMINAL_OFFLINE:
        return "Terminal offline";
      case TRADE_STATE_TRADE_TERMINAL_SHUTDOWN:
        return "Terminal is shutting down";
    }
    return "Unknown!";
  }
  unsigned int GetStates() { return states; }
  // Struct methods for bitwise operations.
  bool CheckState(unsigned int _states) { return (states & _states) != 0 || states == _states; }
  bool CheckStatesAll(unsigned int _states) { return (states & _states) == _states; }
  static bool CheckState(unsigned int _states1, unsigned int _states2) {
    return (_states2 & _states1) != 0 || _states2 == _states1;
  }
  void AddState(unsigned int _states) { states |= _states; }
  void RemoveState(unsigned int _states) { states &= ~_states; }
  void SetState(ENUM_TRADE_STATE _state, bool _value = true) {
    if (_value) {
      AddState(_state);
    } else {
      RemoveState(_state);
    }
  }
  void SetState(unsigned int _states) { states = _states; }
  // Serializers.
  void SerializeStub(int _n1 = 1, int _n2 = 1, int _n3 = 1, int _n4 = 1, int _n5 = 1) {}
  SerializerNodeType Serialize(Serializer &_s) {
    int _size = sizeof(int) * 8;
    for (int i = 0; i < _size; i++) {
      int _value = CheckState(1 << i) ? 1 : 0;
      _s.Pass(this, (string)(i + 1), _value, SERIALIZER_FIELD_FLAG_DYNAMIC);
    }
    return SerializerNodeObject;
  }
};
