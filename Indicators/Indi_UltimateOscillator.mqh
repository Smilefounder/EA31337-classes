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
#include "../Indicator/IndicatorTickOrCandleSource.h"
#include "../Storage/ValueStorage.all.h"
#include "Indi_ATR.mqh"
#include "Indi_MA.mqh"

// Structs.
struct IndiUltimateOscillatorParams : IndicatorParams {
  Ref<IndicatorData> indi_atr_fast;
  Ref<IndicatorData> indi_atr_middle;
  Ref<IndicatorData> indi_atr_slow;
  int fast_period;
  int middle_period;
  int slow_period;
  int fast_k;
  int middle_k;
  int slow_k;

  // Struct constructor.
  IndiUltimateOscillatorParams(int _fast_period = 7, int _middle_period = 14, int _slow_period = 28, int _fast_k = 4,
                               int _middle_k = 2, int _slow_k = 1, int _shift = 0)
      : IndicatorParams(INDI_ULTIMATE_OSCILLATOR) {
    fast_k = _fast_k;
    fast_period = _fast_period;
    middle_k = _middle_k;
    middle_period = _middle_period;
    SetCustomIndicatorName("Examples\\Ultimate_Oscillator");
    shift = _shift;
    slow_k = _slow_k;
    slow_period = _slow_period;
  };
  IndiUltimateOscillatorParams(IndiUltimateOscillatorParams &_params, ENUM_TIMEFRAMES _tf) {
    THIS_REF = _params;
    tf = _tf;
  };
};

/**
 * Implements the Bill Williams' Accelerator/Decelerator oscillator.
 */
class Indi_UltimateOscillator : public IndicatorTickOrCandleSource<IndiUltimateOscillatorParams> {
 public:
  /**
   * Class constructor.
   */
  Indi_UltimateOscillator(IndiUltimateOscillatorParams &_p, ENUM_IDATA_SOURCE_TYPE _idstype = IDATA_BUILTIN,
                          IndicatorData *_indi_src = NULL, int _indi_src_mode = 0)
      : IndicatorTickOrCandleSource(
            _p, IndicatorDataParams::GetInstance(1, TYPE_DOUBLE, _idstype, IDATA_RANGE_MIXED, _indi_src_mode),
            _indi_src){};
  Indi_UltimateOscillator(ENUM_TIMEFRAMES _tf = PERIOD_CURRENT, int _shift = 0)
      : IndicatorTickOrCandleSource(INDI_ULTIMATE_OSCILLATOR, _tf, _shift){};

  /**
   * Built-in version of Ultimate Oscillator.
   */
  static double iUO(string _symbol, ENUM_TIMEFRAMES _tf, int _fast_period, int _middle_period, int _slow_period,
                    int _fast_k, int _middle_k, int _slow_k, int _mode = 0, int _shift = 0,
                    IndicatorData *_obj = NULL) {
    INDICATOR_CALCULATE_POPULATE_PARAMS_AND_CACHE_LONG(
        _symbol, _tf,
        Util::MakeKey("Indi_UltimateOscillator", _fast_period, _middle_period, _slow_period, _fast_k, _middle_k,
                      _slow_k));

    IndicatorData *_indi_atr_fast = Indi_ATR::GetCached(_symbol, _tf, _fast_period);
    IndicatorData *_indi_atr_middle = Indi_ATR::GetCached(_symbol, _tf, _middle_period);
    IndicatorData *_indi_atr_slow = Indi_ATR::GetCached(_symbol, _tf, _slow_period);

    return iUOOnArray(INDICATOR_CALCULATE_POPULATED_PARAMS_LONG, _fast_period, _middle_period, _slow_period, _fast_k,
                      _middle_k, _slow_k, _mode, _shift, _cache, _indi_atr_fast, _indi_atr_middle, _indi_atr_slow);
  }

  /**
   * Calculates Ultimate Oscillator on the array of values.
   */
  static double iUOOnArray(INDICATOR_CALCULATE_PARAMS_LONG, int _fast_period, int _middle_period, int _slow_period,
                           int _fast_k, int _middle_k, int _slow_k, int _mode, int _shift,
                           IndicatorCalculateCache<double> *_cache, IndicatorData *_indi_atr_fast,
                           IndicatorData *_indi_atr_middle, IndicatorData *_indi_atr_slow, bool _recalculate = false) {
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
   * On-indicator version of Ultimate Oscillator.
   */
  static double iUOOnIndicator(IndicatorData *_indi, string _symbol, ENUM_TIMEFRAMES _tf, int _fast_period,
                               int _middle_period, int _slow_period, int _fast_k, int _middle_k, int _slow_k,
                               int _mode = 0, int _shift = 0, IndicatorData *_obj = NULL) {
    INDICATOR_CALCULATE_POPULATE_PARAMS_AND_CACHE_LONG_DS(
        _indi, _symbol, _tf,
        Util::MakeKey("Indi_UltimateOscillator_ON_" + _indi.GetFullName(), _fast_period, _middle_period, _slow_period,
                      _fast_k, _middle_k, _slow_k));

    // @fixit This won't work! Find a way to differentiate ATRs.
    Indi_ATR *_indi_atr_fast = (Indi_ATR *)_indi.GetDataSource(INDI_ULTIMATE_OSCILLATOR_ATR_FAST);
    Indi_ATR *_indi_atr_middle = (Indi_ATR *)_indi.GetDataSource(INDI_ULTIMATE_OSCILLATOR_ATR_MIDDLE);
    Indi_ATR *_indi_atr_slow = (Indi_ATR *)_indi.GetDataSource(INDI_ULTIMATE_OSCILLATOR_ATR_SLOW);

    return iUOOnArray(INDICATOR_CALCULATE_POPULATED_PARAMS_LONG, _fast_period, _middle_period, _slow_period, _fast_k,
                      _middle_k, _slow_k, _mode, _shift, _cache, _indi_atr_fast, _indi_atr_middle, _indi_atr_slow);
  }

  /**
   * Provides built-in indicators whose can be used as data source.
   */
  IndicatorData *FetchDataSource(ENUM_INDICATOR_TYPE _id) override {
    switch (_id) {
      case INDI_ULTIMATE_OSCILLATOR_ATR_FAST:
        return iparams.indi_atr_fast.Ptr();
      case INDI_ULTIMATE_OSCILLATOR_ATR_MIDDLE:
        return iparams.indi_atr_middle.Ptr();
      case INDI_ULTIMATE_OSCILLATOR_ATR_SLOW:
        return iparams.indi_atr_slow.Ptr();
    }
    return NULL;
  }

  /**
   * OnCalculate() method for Ultimate Oscillator.
   */
  static int Calculate(INDICATOR_CALCULATE_METHOD_PARAMS_LONG, ValueStorage<double> &ExtUOBuffer,
                       ValueStorage<double> &ExtBPBuffer, ValueStorage<double> &ExtFastATRBuffer,
                       ValueStorage<double> &ExtMiddleATRBuffer, ValueStorage<double> &ExtSlowATRBuffer,
                       int InpFastPeriod, int InpMiddlePeriod, int InpSlowPeriod, int InpFastK, int InpMiddleK,
                       int InpSlowK, Indi_ATR *ExtFastATRhandle, Indi_ATR *ExtMiddleATRhandle,
                       Indi_ATR *ExtSlowATRhandle) {
    double ExtDivider = InpFastK + InpMiddleK + InpSlowK;
    double true_low;
    int ExtMaxPeriod = InpSlowPeriod;
    if (ExtMaxPeriod < InpMiddlePeriod) ExtMaxPeriod = InpMiddlePeriod;
    if (ExtMaxPeriod < InpFastPeriod) ExtMaxPeriod = InpFastPeriod;

    int min_bars_required = MathMax(MathMax(InpFastPeriod, InpMiddlePeriod), InpSlowPeriod);

    if (rates_total < ExtMaxPeriod) return (0);
    // Not all data may be calculated.
    int calculated = BarsCalculated(ExtFastATRhandle);
    if (calculated < rates_total) {
      // Not all data of ExtFastATRhandle is calculated.
      return (0);
    }
    calculated = BarsCalculated(ExtMiddleATRhandle);
    if (calculated < rates_total) {
      // Not all data of ExtFastATRhandle is calculated.
      return (0);
    }
    calculated = BarsCalculated(ExtSlowATRhandle);
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
  virtual IndicatorDataEntryValue GetEntryValue(int _mode = 0, int _shift = 0) {
    double _value = EMPTY_VALUE;
    int _ishift = _shift >= 0 ? _shift : iparams.GetShift();
    switch (Get<ENUM_IDATA_SOURCE_TYPE>(STRUCT_ENUM(IndicatorDataParams, IDATA_PARAM_IDSTYPE))) {
      case IDATA_BUILTIN:
        _value = Indi_UltimateOscillator::iUO(GetSymbol(), GetTf(), /*[*/ GetFastPeriod(), GetMiddlePeriod(),
                                              GetSlowPeriod(), GetFastK(), GetMiddleK(), GetSlowK() /*]*/, _mode,
                                              _ishift, THIS_PTR);
        break;
      case IDATA_ICUSTOM:
        _value = iCustom(istate.handle, GetSymbol(), GetTf(), iparams.GetCustomIndicatorName(), /*[*/
                         GetFastPeriod(), GetMiddlePeriod(), GetSlowPeriod(), GetFastK(), GetMiddleK(),
                         GetSlowK()
                         /*]*/,
                         0, _ishift);
        break;
      case IDATA_INDICATOR:
        _value = Indi_UltimateOscillator::iUOOnIndicator(GetDataSource(), GetSymbol(), GetTf(), /*[*/ GetFastPeriod(),
                                                         GetMiddlePeriod(), GetSlowPeriod(), GetFastK(), GetMiddleK(),
                                                         GetSlowK() /*]*/, _mode, _ishift, THIS_PTR);
        break;
      default:
        SetUserError(ERR_INVALID_PARAMETER);
    }
    return _value;
  }

  /* Getters */

  /**
   * Get fast period.
   */
  int GetFastPeriod() { return iparams.fast_period; }

  /**
   * Get middle period.
   */
  int GetMiddlePeriod() { return iparams.middle_period; }

  /**
   * Get slow period.
   */
  int GetSlowPeriod() { return iparams.slow_period; }

  /**
   * Get fast k.
   */
  int GetFastK() { return iparams.fast_k; }

  /**
   * Get middle k.
   */
  int GetMiddleK() { return iparams.middle_k; }

  /**
   * Get slow k.
   */
  int GetSlowK() { return iparams.slow_k; }

  /* Setters */

  /**
   * Set fast period.
   */
  void SetFastPeriod(int _fast_period) {
    istate.is_changed = true;
    iparams.fast_period = _fast_period;
  }

  /**
   * Set middle period.
   */
  void SetMiddlePeriod(int _middle_period) {
    istate.is_changed = true;
    iparams.middle_period = _middle_period;
  }

  /**
   * Set slow period.
   */
  void SetSlowPeriod(int _slow_period) {
    istate.is_changed = true;
    iparams.slow_period = _slow_period;
  }

  /**
   * Set fast k.
   */
  void SetFastK(int _fast_k) {
    istate.is_changed = true;
    iparams.fast_k = _fast_k;
  }

  /**
   * Set middle k.
   */
  void SetMiddleK(int _middle_k) {
    istate.is_changed = true;
    iparams.middle_k = _middle_k;
  }

  /**
   * Set slow k.
   */
  void SetSlowK(int _slow_k) {
    istate.is_changed = true;
    iparams.slow_k = _slow_k;
  }
};
