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

// Prevents processing this includes file for the second time.
#ifndef INDI_MA_MQH
#define INDI_MA_MQH

// Includes.
#include "../Dict.mqh"
#include "../DictObject.mqh"
#include "../Indicator.mqh"
#include "../Refs.mqh"
#include "../Singleton.h"
#include "../String.mqh"
#include "../ValueStorage.h"

#ifndef __MQL4__
// Defines global functions (for MQL4 backward compability).
double iMA(string _symbol, int _tf, int _ma_period, int _ma_shift, int _ma_method, int _ap, int _shift) {
  return Indi_MA::iMA(_symbol, (ENUM_TIMEFRAMES)_tf, _ma_period, _ma_shift, (ENUM_MA_METHOD)_ma_method,
                      (ENUM_APPLIED_PRICE)_ap, _shift);
}
double iMAOnArray(double &_arr[], int _total, int _period, int _ma_shift, int _ma_method, int _shift,
                  string cache_name = "") {
  return Indi_MA::iMAOnArray(_arr, _total, _period, _ma_shift, _ma_method, _shift, cache_name);
}
#endif

// Structs.
struct MAParams : IndicatorParams {
  unsigned int period;
  unsigned int ma_shift;
  ENUM_MA_METHOD ma_method;
  ENUM_APPLIED_PRICE applied_price;
  // Struct constructors.
  void MAParams(unsigned int _period = 13, int _ma_shift = 10, ENUM_MA_METHOD _ma_method = MODE_SMA,
                ENUM_APPLIED_PRICE _ap = PRICE_OPEN, int _shift = 0)
      : period(_period), ma_shift(_ma_shift), ma_method(_ma_method), applied_price(_ap) {
    itype = INDI_MA;
    max_modes = 1;
    shift = _shift;
    SetDataValueType(TYPE_DOUBLE);
    SetDataValueRange(IDATA_RANGE_PRICE);
    SetCustomIndicatorName("Examples\\Moving Average");
  };
  void MAParams(MAParams &_params, ENUM_TIMEFRAMES _tf = PERIOD_CURRENT) {
    this = _params;
    tf = _tf;
  };
};

/**
 * Implements the Moving Average indicator.
 */
class Indi_MA : public Indicator {
 protected:
  MAParams params;

 public:
  /**
   * Class constructor.
   */
  Indi_MA(MAParams &_p) : params(_p.period, _p.shift, _p.ma_method, _p.applied_price), Indicator((IndicatorParams)_p) {
    params = _p;
  }
  Indi_MA(MAParams &_p, ENUM_TIMEFRAMES _tf)
      : params(_p.period, _p.shift, _p.ma_method, _p.applied_price), Indicator(INDI_MA, _tf) {
    params = _p;
  }

  /**
   * Returns the indicator value.
   *
   * @docs
   * - https://docs.mql4.com/indicators/ima
   * - https://www.mql5.com/en/docs/indicators/ima
   */
  static double iMA(string _symbol, ENUM_TIMEFRAMES _tf, unsigned int _ma_period, unsigned int _ma_shift,
                    ENUM_MA_METHOD _ma_method, ENUM_APPLIED_PRICE _applied_price, int _shift = 0,
                    Indicator *_obj = NULL) {
    ResetLastError();
#ifdef __MQL4__
    return ::iMA(_symbol, _tf, _ma_period, _ma_shift, _ma_method, _applied_price, _shift);
#else  // __MQL5__
    int _handle = Object::IsValid(_obj) ? _obj.GetState().GetHandle() : NULL;
    double _res[];
    ResetLastError();
    if (_handle == NULL || _handle == INVALID_HANDLE) {
      if ((_handle = ::iMA(_symbol, _tf, _ma_period, _ma_shift, _ma_method, _applied_price)) == INVALID_HANDLE) {
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
   * Calculates MA on another indicator.
   *
   * We are operating on given indicator's data. To select which buffer we use,
   * we need to set "indi_mode" parameter for current indicator. It defaults to
   * 0 (the first value). For example: if Price indicator has four values
   * (OHCL), we can use this indicator to operate over Price indicator, and set
   * indi_mode to e.g., PRICE_LOW or PRICE_CLOSE.
   */
  static double iMAOnIndicator(Indicator *_indi, string _symbol, ENUM_TIMEFRAMES _tf, unsigned int _ma_period,
                               unsigned int _ma_shift,
                               ENUM_MA_METHOD _ma_method,  // (MT4/MT5): MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA
                               int _shift = 0, Indicator *_obj = NULL, string _cache_name = "") {
    double result = 0;
    double indi_values[];
    ArrayResize(indi_values, _ma_period + _ma_shift + _shift);

    for (int i = 0; i < (int)_ma_period + (int)_ma_shift + _shift; ++i) {
      indi_values[i] = _indi[i][0];
    }

    return iMAOnArray(indi_values, 0, _ma_period, _ma_shift, _ma_method, _shift, _cache_name);
  }

  /**
   * Calculates MA on the array of values.
   */
  static double iMAOnArray(double &price[], int total, int period, int ma_shift, int ma_method, int shift,
                           string cache_name = "") {
    
    // Note that price array is cloned each time iMAOnArray is called. If you want better performance,
    // use ValueStorage objects to store prices and Indicator::GetBufferValueStorage(index) method to store other buffers for direct value access.
    
    NativeValueStorage<double>* _price = Singleton<NativeValueStorage<double>>::Get();
    _price.SetData(price);
    
    return iMAOnArray((ValueStorage<double>*)_price, total, period, ma_shift, ma_method, shift, cache_name);
  }

  /**
   * Calculates MA on the array of values.
   */
  static double iMAOnArray(ValueStorage<double> &price, int total, int period, int ma_shift, int ma_method, int shift,
                           string cache_name = "") {
#ifdef __MQL4__
    double _price[];
    price.ExportTo(_price);
    return ::iMAOnArray( _price, total, period, ma_shift, ma_method, shift);
#else

    if (cache_name != "") {
      String cache_key;
      // Do not add shifts here! It would invalidate cache for each call and break the whole algorithm.
      cache_key.Add(cache_name);
      cache_key.Add(period);
      cache_key.Add(ma_method);
      
      //IndicatorCalculateCache<double>& cache = IndicatorCalculateCache<double>::Unique(cache_key.ToString());
      
      static IndicatorCalculateCache<double> cache;
      
      if (!cache.IsInitialized()) {
        // Price could be fetched from native array or Indicator's buffer via Indicator::GetBufferValueStorage(index).
        // E.g.: cache.SetPriceBuffer(_indi.GetBufferValueStorage(0));
        cache.SetPriceBuffer(&price);
        cache.AddBuffer((ValueStorage<double>*)new NativeValueStorage<double>());
      }
      
      // Will resize buffers.
      //cache.SetTotal(total);

      cache.SetPrevCalculated(Indi_MA::Calculate(
        cache.GetTotal(),
        cache.GetPrevCalculated(),
        0,
        cache.GetPriceBuffer(),
        cache.GetBuffer(0),
        ma_method,
        period
      ));

      // Returns value from the first calculation buffer.
      // Returns first value for as-series array or last value for non-as-series array.
      return cache.GetTailValue(0, shift + ma_shift);
    }

    double buf[], arr[], _result, pr, _price;
    int pos, i, k, weight;
    double sum, lsum;
    if (total == 0) total = ArraySize(price);
    if (total > 0 && total < period) return (0);
    if (shift > total - period - ma_shift) return (0);
    bool _was_series = ArrayGetAsSeries(price);
    ArraySetAsSeries(price, true);
    switch (ma_method) {
      case MODE_SMA:
        total = ArrayCopy(arr, price, 0, shift + ma_shift, period);
        if (ArrayResize(buf, total) < 0) return (0);
        sum = 0;
        pos = total - 1;
        for (i = 1; i < period; i++, pos--) sum += arr[pos];
        while (pos >= 0) {
          sum += arr[pos];
          buf[pos] = sum / period;
          sum -= arr[pos + period - 1];
          pos--;
        }
        _result = buf[0];
        break;
      case MODE_EMA:
        if (ArrayResize(buf, total) < 0) return (0);
        pr = 2.0 / (period + 1);
        pos = total - 2;
        while (pos >= 0) {
          if (pos == total - 2) buf[pos + 1] = price[pos + 1].Get();
          buf[pos] = price[pos] * pr + buf[pos + 1] * (1 - pr);
          pos--;
        }
        _result = buf[0];
        break;
      case MODE_SMMA:
        if (ArrayResize(buf, total) < 0) return (0);
        sum = 0;
        pos = total - period;
        while (pos >= 0) {
          if (pos == total - period) {
            for (i = 0, k = pos; i < period; i++, k++) {
              sum += price[k].Get();
              buf[k] = 0;
            }
          } else
            sum = buf[pos + 1] * (period - 1) + price[pos].Get();
          buf[pos] = sum / period;
          pos--;
        }
        _result = buf[0];
        break;
      case MODE_LWMA:
        if (ArrayResize(buf, total) < 0) return (0);
        sum = 0.0;
        lsum = 0.0;
        weight = 0;
        pos = total - 1;
        for (i = 1; i <= period; i++, pos--) {
          _price = price[pos].Get();
          sum += _price * i;
          lsum += _price;
          weight += i;
        }
        pos++;
        i = pos + period;
        while (pos >= 0) {
          buf[pos] = sum / weight;
          if (pos == 0) break;
          pos--;
          i--;
          _price = price[pos].Get();
          sum = sum - lsum + _price * period;
          lsum -= price[i].Get();
          lsum += _price;
        }
        _result = buf[0];
        break;
      default:
        _result = 0;
    }
    ArraySetAsSeries(price, _was_series);
    return _result;
#endif
  }

  /**
   * Calculates Simple Moving Average (SMA). The same as in "Example Moving Average" indicator.
   */
  static void CalculateSimpleMA(int rates_total, int prev_calculated, int begin, ValueStorage<double> &price,
                                ValueStorage<double> &ExtLineBuffer, int InpMAPeriod) {
   int i,start;
//--- first calculation or number of bars was changed
   if(prev_calculated==0)
     {
      start=InpMAPeriod+begin;
      //--- set empty value for first start bars
      for(i=0; i<start-1; i++)
         ExtLineBuffer[i]=0.0;
      //--- calculate first visible value
      double first_value=0;
      for(i=begin; i<start; i++)
         first_value+=price[i].Get();
      first_value/=InpMAPeriod;
      ExtLineBuffer[start-1]=first_value;
     }
   else
      start=prev_calculated-1;
//--- main loop
   for(i=start; i<rates_total && !IsStopped(); i++)
      ExtLineBuffer[i]=ExtLineBuffer[i-1]+(price[i]-price[i-(InpMAPeriod - 1)])/InpMAPeriod;
  }

  /**
   * Calculates Exponential Moving Average (EMA). The same as in "Example Moving Average" indicator.
   */
  static void CalculateEMA(int rates_total, int prev_calculated, int begin, ValueStorage<double> &price,
                           ValueStorage<double> &ExtLineBuffer, int InpMAPeriod) {
    int i, limit;
    double SmoothFactor = 2.0 / (1.0 + InpMAPeriod);
    //--- first calculation or number of bars was changed
    if (prev_calculated == 0) {
      limit = InpMAPeriod + begin;
      ExtLineBuffer[begin] = price[begin];
      for (i = begin + 1; i < limit; i++)
        ExtLineBuffer[i] = price[i] * SmoothFactor + ExtLineBuffer[i - 1] * (1.0 - SmoothFactor);
    } else
      limit = prev_calculated - 1;
    //--- main loop
    for (i = limit; i < rates_total && !IsStopped(); i++)
      ExtLineBuffer[i] = price[i] * SmoothFactor + ExtLineBuffer[i - 1] * (1.0 - SmoothFactor);
    //---
  }

  /**
   * Calculates Linearly Weighted Moving Average (LWMA). The same as in "Example Moving Average" indicator.
   */
  static void CalculateLWMA(int rates_total, int prev_calculated, int begin, ValueStorage<double> &price,
                            ValueStorage<double> &ExtLineBuffer, int InpMAPeriod) {
    int i, limit;
    static int weightsum;
    double sum;
    //--- first calculation or number of bars was changed
    if (prev_calculated == 0) {
      weightsum = 0;
      limit = InpMAPeriod + begin;
      //--- set empty value for first limit bars
      for (i = 0; i < limit; i++) ExtLineBuffer[i] = 0.0;
      //--- calculate first visible value
      double firstValue = 0;
      for (i = begin; i < limit; i++) {
        int k = i - begin + 1;
        weightsum += k;
        firstValue += k * price[i].Get();
      }
      firstValue /= (double)weightsum;
      ExtLineBuffer[limit - 1] = firstValue;
    } else
      limit = prev_calculated - 1;
    //--- main loop
    for (i = limit; i < rates_total && !IsStopped(); i++) {
      sum = 0;
      for (int j = 0; j < InpMAPeriod; j++) sum += (InpMAPeriod - j) * price[i - j].Get();
      ExtLineBuffer[i] = sum / weightsum;
    }
    //---
  }

  /**
   * Calculates Smoothed Moving Average (SMMA). The same as in "Example Moving Average" indicator.
   */
  static void CalculateSmoothedMA(int rates_total, int prev_calculated, int begin, ValueStorage<double> &price,
                                  ValueStorage<double> &ExtLineBuffer, int InpMAPeriod) {
    int i, limit;
    //--- first calculation or number of bars was changed
    if (prev_calculated == 0) {
      limit = InpMAPeriod + begin;
      //--- set empty value for first limit bars
      for (i = 0; i < limit - 1; i++) ExtLineBuffer[i] = 0.0;
      //--- calculate first visible value
      double firstValue = 0;
      for (i = begin; i < limit; i++) firstValue += price[i].Get();
      firstValue /= InpMAPeriod;
      ExtLineBuffer[limit - 1] = firstValue;
    } else
      limit = prev_calculated - 1;
    //--- main loop
    for (i = limit; i < rates_total && !IsStopped(); i++)
      ExtLineBuffer[i] = (ExtLineBuffer[i - 1] * (InpMAPeriod - 1) + price[i].Get()) / InpMAPeriod;
    //---
  }

  static int ExponentialMAOnBuffer(const int rates_total, const int prev_calculated, const int begin, const int period,
                                   ValueStorage<double> &price, ValueStorage<double> &buffer) {
    if (period <= 1 || period > (rates_total - begin)) return (0);

    bool as_series_price = ArrayGetAsSeries(price);
    bool as_series_buffer = ArrayGetAsSeries(buffer);

    ArraySetAsSeries(price, false);
    ArraySetAsSeries(buffer, false);

    int start_position, i;
    double smooth_factor = 2.0 / (1.0 + period);

    if (prev_calculated == 0)  // first calculation or number of bars was changed
    {
      //--- set empty value for first bars
      for (i = 0; i < begin; i++) buffer[i] = 0.0;
      //--- calculate first visible value
      start_position = period + begin;
      buffer[begin] = price[begin];

      for (i = begin + 1; i < start_position; i++)
        buffer[i] = price[i] * smooth_factor + buffer[i - 1] * (1.0 - smooth_factor);
    } else
      start_position = prev_calculated - 1;

    for (i = start_position; i < rates_total; i++)
      buffer[i] = price[i] * smooth_factor + buffer[i - 1] * (1.0 - smooth_factor);

    ArraySetAsSeries(price, as_series_price);
    ArraySetAsSeries(buffer, as_series_buffer);

    return (rates_total);
  }

  /**
   * Calculates Moving Average. The same as in "Example Moving Average" indicator.
   */
  static int Calculate(const int rates_total, const int prev_calculated, const int begin, ValueStorage<double> &price,
                       ValueStorage<double> &ExtLineBuffer, int InpMAMethod, int InpMAPeriod) {
    //--- check for bars count
    if (rates_total < InpMAPeriod - 1 + begin)
      return (0);  // not enough bars for calculation
                   //--- first calculation or number of bars was changed
    if (prev_calculated == 0) ArrayInitialize(ExtLineBuffer, (double)0);

    //--- calculation
    switch (InpMAMethod) {
      case MODE_EMA:
        CalculateEMA(rates_total, prev_calculated, begin, price, ExtLineBuffer, InpMAPeriod);
        break;
      case MODE_LWMA:
        CalculateLWMA(rates_total, prev_calculated, begin, price, ExtLineBuffer, InpMAPeriod);
        break;
      case MODE_SMMA:
        CalculateSmoothedMA(rates_total, prev_calculated, begin, price, ExtLineBuffer, InpMAPeriod);
        break;
      case MODE_SMA:
        CalculateSimpleMA(rates_total, prev_calculated, begin, price, ExtLineBuffer, InpMAPeriod);
        break;
    }
    //--- return value of prev_calculated for next call
    return (rates_total);
  }

  static double SimpleMA(const int position, const int period, const double &price[]) {
    double result = 0.0;
    for (int i = 0; i < period; i++) {
      result += price[i];
    }
    result /= period;
    return result;
  }

  /**
   * Returns the indicator's value.
   */
  double GetValue(int _shift = 0) {
    ResetLastError();
    double _value = EMPTY_VALUE;
    switch (params.idstype) {
      case IDATA_BUILTIN:
        istate.handle = istate.is_changed ? INVALID_HANDLE : istate.handle;
        _value = Indi_MA::iMA(Get<string>(CHART_PARAM_SYMBOL), Get<ENUM_TIMEFRAMES>(CHART_PARAM_TF), GetPeriod(),
                              GetMAShift(), GetMAMethod(), GetAppliedPrice(), _shift, GetPointer(this));
        break;
      case IDATA_ICUSTOM:
        istate.handle = istate.is_changed ? INVALID_HANDLE : istate.handle;
        _value = iCustom(istate.handle, Get<string>(CHART_PARAM_SYMBOL), Get<ENUM_TIMEFRAMES>(CHART_PARAM_TF),
                         params.custom_indi_name, /* [ */ GetPeriod(), GetMAShift(), GetMAMethod(),
                         GetAppliedPrice() /* ] */, 0, _shift);
        break;
      case IDATA_INDICATOR:
        // Calculating MA value from specified indicator.
        Print(GetFullName());
        _value = Indi_MA::iMAOnIndicator(GetDataSource(), Get<string>(CHART_PARAM_SYMBOL),
                                         Get<ENUM_TIMEFRAMES>(CHART_PARAM_TF), GetPeriod(), GetMAShift(), GetMAMethod(),
                                         _shift, GetPointer(this), CacheKey());
        break;
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
      _entry.values[0] = GetValue(_shift);
      _entry.SetFlag(INDI_ENTRY_FLAG_IS_VALID, !_entry.HasValue<double>(NULL) &&
                                                   !_entry.HasValue<double>(EMPTY_VALUE) &&
                                                   !_entry.HasValue<double>(DBL_MAX));
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
    GetEntry(_shift).values[_mode].Get(_param.double_value);
    return _param;
  }

  /* Getters */

  /**
   * Get period value.
   *
   * Averaging period for the calculation of the moving average.
   */
  unsigned int GetPeriod() { return params.period; }

  /**
   * Get MA shift value.
   *
   * Indicators line offset relate to the chart by timeframe.
   */
  unsigned int GetMAShift() { return params.ma_shift; }

  /**
   * Set MA method (smoothing type).
   */
  ENUM_MA_METHOD GetMAMethod() { return params.ma_method; }

  /**
   * Get applied price value.
   *
   * The desired price base for calculations.
   */
  ENUM_APPLIED_PRICE GetAppliedPrice() { return params.applied_price; }

  /* Setters */

  /**
   * Set period value.
   *
   * Averaging period for the calculation of the moving average.
   */
  void SetPeriod(unsigned int _period) {
    istate.is_changed = true;
    params.period = _period;
  }

  /**
   * Set MA shift value.
   */
  void SetMAShift(int _ma_shift) {
    istate.is_changed = true;
    params.ma_shift = _ma_shift;
  }

  /**
   * Set MA method.
   *
   * Indicators line offset relate to the chart by timeframe.
   */
  void SetMAMethod(ENUM_MA_METHOD _ma_method) {
    istate.is_changed = true;
    params.ma_method = _ma_method;
  }

  /**
   * Set applied price value.
   *
   * The desired price base for calculations.
   * @docs
   * - https://docs.mql4.com/constants/indicatorconstants/prices#enum_applied_price_enum
   * - https://www.mql5.com/en/docs/constants/indicatorconstants/prices#enum_applied_price_enum
   */
  void SetAppliedPrice(ENUM_APPLIED_PRICE _applied_price) {
    istate.is_changed = true;
    params.applied_price = _applied_price;
  }
};
#endif  // INDI_MA_MQH
