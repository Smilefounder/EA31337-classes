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

/**
 * @file
 * Provides a base class for a task's getter.
 */

#ifndef __MQL__
// Allows the preprocessor to include a header file when it is needed.
#pragma once
#endif

// Prevents processing this includes file for the second time.
#ifndef TASK_GETTER_BASE_H
#define TASK_GETTER_BASE_H

// Includes.
#include "TaskGetter.struct.h"

/**
 * TaskGetterBase class.
 */
template <typename TS>
class TaskGetterBase {
 public:
  /* Special methods */

  /**
   * Class constructor.
   */
  TaskGetterBase() {}

  /* Main methods */

  /**
   * Gets a copy of structure.
   */
  virtual TS Get(const TaskGetterEntry &_entry) = 0;
};

#endif  // TASK_GETTER_BASE_H
