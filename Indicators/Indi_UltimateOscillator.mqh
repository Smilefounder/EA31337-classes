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
#include "Indi_ATR.mqh"

// Structs.
struct UltimateOscillatorParams : IndicatorParams {
  int fast_period;
  int middle_period;
  int slow_period;
  int fast_k;
  int middle_k;
  int slow_k;

  // Struct constructor.
  void UltimateOscillatorParams(int _fast_period = 7, int _middle_period = 14, int _slow_period = 28, int _fast_k = 4,
                                int _middle_k = 2, int _slow_k = 1, int _shift = 0) {
    fast_k = _fast_k;
    fast_period = _fast_period;
    itype = INDI_ULTIMATE_OSCILLATOR;
    max_modes = 1;
    middle_k = _middle_k;
    middle_period = _middle_period;
    SetDataValueType(TYPE_DOUBLE);
    SetDataValueRange(IDATA_RANGE_MIXED);
    SetCustomIndicatorName("Examples\\Ultimate_Oscillator");
    shift = _shift;
    slow_k = _slow_k;
    slow_period = _slow_period;
  };
};

/**
 * Implements the Bill Williams' Accelerator/Decelerator oscillator.
 */
class Indi_UltimateOscillator : public Indicator {
 protected:
  UltimateOscillatorParams params;

 public:
  /**
   * Class constructor.
   */
  Indi_UltimateOscillator(UltimateOscillatorParams &_params, ENUM_TIMEFRAMES _tf = PERIOD_CURRENT)
      : Indicator((IndicatorParams)_params, _tf) {
    params = _params;
  };
  Indi_UltimateOscillator(ENUM_TIMEFRAMES _tf = PERIOD_CURRENT) : Indicator(INDI_ULTIMATE_OSCILLATOR, _tf){};

  /**
   * Built-in version of Ultimate Oscillator.
   */
  static double iUO(string _symbol, ENUM_TIMEFRAMES _tf, int _fast_period, int _middle_period, int _slow_period,
                    int _fast_k, int _middle_k, int _slow_k, int _mode = 0, int _shift = 0, Indicator *_obj = NULL) {
    INDICATOR_CALCULATE_POPULATE_PARAMS_AND_CACHE_LONG(
        _symbol, _tf,
        Util::MakeKey("Indi_UltimateOscillator", _fast_period, _middle_period, _slow_period, _fast_k, _middle_k,
                      _slow_k));

    Indicator *_indi_atr_fast = Indi_ATR::GetCached(_symbol, _tf, _fast_period);
    Indicator *_indi_atr_middle = Indi_ATR::GetCached(_symbol, _tf, _middle_period);
    Indicator *_indi_atr_slow = Indi_ATR::GetCached(_symbol, _tf, _slow_period);

    return iUOOnArray(INDICATOR_CALCULATE_POPULATED_PARAMS_LONG, _fast_period, _middle_period, _slow_period, _fast_k,
                      _middle_k, _slow_k, _mode, _shift, _cache, _indi_atr_fast, _indi_atr_middle, _indi_atr_slow);
  }

  /**
   * Calculates Ultimate Oscillator on the array of values.
   */
  static double iUOOnArray(INDICATOR_CALCULATE_PARAMS_LONG, int _fast_period, int _middle_period, int _slow_period,
                           int _fast_k, int _middle_k, int _slow_k, int _mode, int _shift,
                           IndicatorCalculateCache<double> *_cache, Indicator *_indi_atr_fast,
                           Indicator *_indi_atr_middle, Indicator *_indi_atr_slow, bool _recalculate = false) {
    _cache.SetPriceBuffer(_open, _high, _low, _close);

    if (!_cache.HasBuffers()) {
      _cache.AddBuffer<NativeValueStorage<double>>(1 + 4);
    }

    if (_recalculate) {
      _cache.ResetPrevCalculated();
    }

    _cache.SetPrevCalculated(Indi_UltimateOscillator::Calculate(
        INDICATOR_CALCULATE_GET_PARAMS_LONG, _cache.GetBuffer<double>(0), _cache.GetBuffer<double>(1),
        _cache.GetBuffer<double>(2), _cache.GetBuffer<double>(3), _cache.GetBuffer<double>(4), _fast_period,
        _middle_period, _slow_period, _fast_k, _middle_k, _slow_k, _indi_atr_fast, _indi_atr_middle, _indi_atr_slow));

    return _cache.GetTailValue<double>(_mode, _shift);
  }

  /**
   * OnCalculate() method for Ultimate Oscillator.
   */
  static int Calculate(INDICATOR_CALCULATE_METHOD_PARAMS_LONG, ValueStorage<double> &ExtUOBuffer,
                       ValueStorage<double> &ExtBPBuffer, ValueStorage<double> &ExtFastATRBuffer,
                       ValueStorage<double> &ExtMiddleATRBuffer, ValueStorage<double> &ExtSlowATRBuffer,
                       int InpFastPeriod, int InpMiddlePeriod, int InpSlowPeriod, int InpFastK, int InpMiddleK,
                       int InpSlowK, Indicator *ExtFastATRhandle, Indicator *ExtMiddleATRhandle,
                       Indicator *ExtSlowATRhandle) {
    double ExtDivider = InpFastK + InpMiddleK + InpSlowK;
    double true_low;
    int ExtMaxPeriod = InpSlowPeriod;
    if (ExtMaxPeriod < InpMiddlePeriod) ExtMaxPeriod = InpMiddlePeriod;
    if (ExtMaxPeriod < InpFastPeriod) ExtMaxPeriod = InpFastPeriod;

    if (rates_total < ExtMaxPeriod) return (0);
    // Not all data may be calculated.
    int calculated = BarsCalculated(ExtFastATRhandle, rates_total);
    if (calculated < rates_total) {
      // Not all data of ExtFastATRhandle is calculated.
      return (0);
    }
    calculated = BarsCalculated(ExtMiddleATRhandle, rates_total);
    if (calculated < rates_total) {
      // Not all data of ExtFastATRhandle is calculated.
      return (0);
    }
    calculated = BarsCalculated(ExtSlowATRhandle, rates_total);
    if (calculated < rates_total) {
      // Not all data of ExtFastATRhandle is calculated.
      return (0);
    }
    // We can copy not all data.
    int to_copy;
    if (prev_calculated > rates_total || prev_calculated < 0)
      to_copy = rates_total;
    else {
      to_copy = rates_total - prev_calculated;
      if (prev_calculated > 0) to_copy++;
    }
    // Get ATR buffers.
    if (IsStopped()) return (0);
    if (CopyBuffer(ExtFastATRhandle, 0, 0, to_copy, ExtFastATRBuffer, rates_total) <= 0) {
      Print("getting ExtFastATRhandle is failed! Error ", GetLastError());
      return (0);
    }

    if (IsStopped()) return (0);
    if (CopyBuffer(ExtMiddleATRhandle, 0, 0, to_copy, ExtMiddleATRBuffer, rates_total) <= 0) {
      Print("getting ExtMiddleATRhandle is failed! Error ", GetLastError());
      return (0);
    }
    if (IsStopped()) return (0);
    if (CopyBuffer(ExtSlowATRhandle, 0, 0, to_copy, ExtSlowATRBuffer, rates_total) <= 0) {
      Print("getting ExtSlowATRhandle is failed! Error ", GetLastError());
      return (0);
    }
    // Preliminary calculations.
    int i, start;
    if (prev_calculated == 0) {
      ExtBPBuffer[0] = 0.0;
      ExtUOBuffer[0] = 0.0;
      // Set value for first InpSlowPeriod bars.
      for (i = 1; i <= InpSlowPeriod; i++) {
        ExtUOBuffer[i] = 0.0;
        true_low = MathMin(low[i].Get(), close[i - 1].Get());
        ExtBPBuffer[i] = close[i] - true_low;
      }
      // Now we are going to calculate from start index in main loop.
      start = InpSlowPeriod + 1;
    } else
      start = prev_calculated - 1;
    // The main loop of calculations.
    for (i = start; i < rates_total && !IsStopped(); i++) {
      true_low = MathMin(low[i].Get(), close[i - 1].Get());
      // Buying pressure.
      ExtBPBuffer[i] = close[i] - true_low;

      if (ExtFastATRBuffer[i] != 0.0 && ExtMiddleATRBuffer[i] != 0.0 && ExtSlowATRBuffer[i] != 0.0) {
        double raw_uo = InpFastK * Indi_MA::SimpleMA(i, InpFastPeriod, ExtBPBuffer) / ExtFastATRBuffer[i].Get() +
                        InpMiddleK * Indi_MA::SimpleMA(i, InpMiddlePeriod, ExtBPBuffer) / ExtMiddleATRBuffer[i].Get() +
                        InpSlowK * Indi_MA::SimpleMA(i, InpSlowPeriod, ExtBPBuffer) / ExtSlowATRBuffer[i].Get();
        ExtUOBuffer[i] = raw_uo / ExtDivider * 100;
      } else
        // Set current Ultimate value as previous Ultimate value.
        ExtUOBuffer[i] = ExtUOBuffer[i - 1];
    }
    // OnCalculate done. Return new prev_calculated.
    return (rates_total);
  }

  /**
   * Returns the indicator's value.
   */
  double GetValue(int _mode = 0, int _shift = 0) {
    ResetLastError();
    double _value = EMPTY_VALUE;
    switch (params.idstype) {
      case IDATA_BUILTIN:
        _value = Indi_UltimateOscillator::iUO(GetSymbol(), GetTf(), /*[*/ GetFastPeriod(), GetMiddlePeriod(),
                                              GetSlowPeriod(), GetFastK(), GetMiddleK(), GetSlowK() /*]*/, _mode,
                                              _shift, THIS_PTR);
        break;
      case IDATA_ICUSTOM:
        _value = iCustom(istate.handle, GetSymbol(), GetTf(), params.GetCustomIndicatorName(), /*[*/
                         GetFastPeriod(), GetMiddlePeriod(), GetSlowPeriod(), GetFastK(), GetMiddleK(),
                         GetSlowK()
                         /*]*/,
                         0, _shift);
        break;
      default:
        SetUserError(ERR_INVALID_PARAMETER);
    }
    istate.is_ready = _LastError == ERR_NO_ERROR;
    istate.is_changed = false;
    return _value;
  }

  /**
   * Returns the indicator's struct value.
   */
  IndicatorDataEntry GetEntry(int _shift = 0) {
    long _bar_time = GetBarTime(_shift);
    unsigned int _position;
    IndicatorDataEntry _entry(params.max_modes);
    if (idata.KeyExists(_bar_time, _position)) {
      _entry = idata.GetByPos(_position);
    } else {
      _entry.timestamp = GetBarTime(_shift);
      for (int _mode = 0; _mode < (int)params.max_modes; _mode++) {
        _entry.values[_mode] = GetValue(_mode, _shift);
      }
      _entry.SetFlag(INDI_ENTRY_FLAG_IS_VALID, !_entry.HasValue<double>(NULL) && !_entry.HasValue<double>(EMPTY_VALUE));
      if (_entry.IsValid()) {
        _entry.AddFlags(_entry.GetDataTypeFlag(params.GetDataValueType()));
        idata.Add(_entry, _bar_time);
      }
    }
    return _entry;
  }

  /**
   * Returns the indicator's entry value.
   */
  MqlParam GetEntryValue(int _shift = 0, int _mode = 0) {
    MqlParam _param = {TYPE_DOUBLE};
    _param.double_value = GetEntry(_shift)[_mode];
    return _param;
  }

  /* Getters */

  /**
   * Get fast period.
   */
  int GetFastPeriod() { return params.fast_period; }

  /**
   * Get middle period.
   */
  int GetMiddlePeriod() { return params.middle_period; }

  /**
   * Get slow period.
   */
  int GetSlowPeriod() { return params.slow_period; }

  /**
   * Get fast k.
   */
  int GetFastK() { return params.fast_k; }

  /**
   * Get middle k.
   */
  int GetMiddleK() { return params.middle_k; }

  /**
   * Get slow k.
   */
  int GetSlowK() { return params.slow_k; }

  /* Setters */

  /**
   * Set fast period.
   */
  void SetFastPeriod(int _fast_period) {
    istate.is_changed = true;
    params.fast_period = _fast_period;
  }

  /**
   * Set middle period.
   */
  void SetMiddlePeriod(int _middle_period) {
    istate.is_changed = true;
    params.middle_period = _middle_period;
  }

  /**
   * Set slow period.
   */
  void SetSlowPeriod(int _slow_period) {
    istate.is_changed = true;
    params.slow_period = _slow_period;
  }

  /**
   * Set fast k.
   */
  void SetFastK(int _fast_k) {
    istate.is_changed = true;
    params.fast_k = _fast_k;
  }

  /**
   * Set middle k.
   */
  void SetMiddleK(int _middle_k) {
    istate.is_changed = true;
    params.middle_k = _middle_k;
  }

  /**
   * Set slow k.
   */
  void SetSlowK(int _slow_k) {
    istate.is_changed = true;
    params.slow_k = _slow_k;
  }
};
