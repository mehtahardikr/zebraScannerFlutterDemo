package com.hm.zebrascannerdemo.zebrascannerdemo.utils

import com.google.gson.Gson

object Utils {
    fun toJsonString( data: Any):String  = Gson().toJson(data)
}