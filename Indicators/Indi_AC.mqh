//+------------------------------------------------------------------+
//|                                                EA31337 framework |
//|                                 Copyright 2016-2021, EA31337 Ltd |
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

// Includes.
#include "../BufferStruct.mqh"
#include "../Indicator.mqh"

#ifndef __MQL4__
// Defines global functions (for MQL4 backward compability).
double iAC(string _symbol, int _tf, int _shift) { return Indi_AC::iAC(_symbol, (ENUM_TIMEFRAMES)_tf, _shift); }
#endif

// Structs.
struct ACParams : IndicatorParams {
  // Struct constructor.
  void ACParams(int _shift = 0) : IndicatorParams(INDI_AC, 1, TYPE_DOUBLE) {
    SetDataValueRange(IDATA_RANGE_MIXED);
    SetCustomIndicatorName("Examples\\Accelerator");
    shift = _shift;
  };
};

/**
 * Implements the Bill Williams' Accelerator/Decelerator oscillator.
 */
class Indi_AC : public Indicator<ACParams> {
 public:
  /**
   * Class constructor.
   */
  Indi_AC(ACParams &_p, IndicatorBase *_indi_src = NULL) : Indicator<ACParams>(_p, _indi_src){};
  Indi_AC(ENUM_TIMEFRAMES _tf = PERIOD_CURRENT) : Indicator(INDI_AC, _tf){};

  /**
   * Returns the indicator value.
   *
   * @docs
   * - https://docs.mql4.com/indicators/iac
   * - https://www.mql5.com/en/docs/indicators/iac
   */
  static double iAC(string _symbol = NULL, ENUM_TIMEFRAMES _tf = PERIOD_CURRENT, int _shift = 0,
                    IndicatorBase *_obj = NULL) {
#ifdef __MQL4__
    return ::iAC(_symbol, _tf, _shift);
#else  // __MQL5__
    int _handle = Object::IsValid(_obj) ? _obj.Get<int>(IndicatorState::INDICATOR_STATE_PROP_HANDLE) : NULL;
    double _res[];
    ResetLastError();
    if (_handle == NULL || _handle == INVALID_HANDLE) {
      if ((_handle = ::iAC(_symbol, _tf)) == INVALID_HANDLE) {
        SetUserError(ERR_USER_INVALID_HANDLE);
        return EMPTY_VALUE;
      } else if (Object::IsValid(_obj)) {
        _obj.SetHandle(_handle);
      }
    }
    if (Terminal::IsVisualMode()) {
      // To avoid error 4806 (ERR_INDICATOR_DATA_NOT_FOUND),
      // we check the number of calculated data only in visual mode.
      int _bars_calc = BarsCalculated(_handle);
      if (GetLastError() > 0) {
        return EMPTY_VALUE;
      } else if (_bars_calc <= 2) {
        SetUserError(ERR_USER_INVALID_BUFF_NUM);
        return EMPTY_VALUE;
      }
    }
    if (CopyBuffer(_handle, 0, _shift, 1, _res) < 0) {
      return EMPTY_VALUE;
    }
    return _res[0];
#endif
  }

  /**
   * Returns the indicator's value.
   */
  double GetValue(int _mode = 0, int _shift = 0) {
    ResetLastError();
    double _value = EMPTY_VALUE;
    switch (iparams.idstype) {
      case IDATA_BUILTIN:
        istate.handle = istate.is_changed ? INVALID_HANDLE : istate.handle;
        _value = Indi_AC::iAC(GetSymbol(), GetTf(), _shift, THIS_PTR);
        break;
      case IDATA_ICUSTOM:
        _value = iCustom(istate.handle, GetSymbol(), GetTf(), iparams.GetCustomIndicatorName(), _mode, _shift);
        break;
      default:
        SetUserError(ERR_INVALID_PARAMETER);
    }
    istate.is_ready = _LastError == ERR_NO_ERROR;
    istate.is_changed = false;
    return _value;
  }

  /**
   * Returns reusable indicator for a given symbol and time-frame.
   */
  static Indi_AC *GetCached(string _symbol, ENUM_TIMEFRAMES _tf) {
    Indi_AC *_ptr;
    string _key = Util::MakeKey(_symbol, (int)_tf);
    if (!Objects<Indi_AC>::TryGet(_key, _ptr)) {
      _ptr = Objects<Indi_AC>::Set(_key, new Indi_AC(_tf));
    }
    return _ptr;
  }

  /**
   * Returns the indicator's entry value.
   */
  MqlParam GetEntryValue(int _shift = 0, int _mode = 0) {
    MqlParam _param = {TYPE_DOUBLE};
    _param.double_value = GetEntry(_shift)[_mode];
    return _param;
  }
};
