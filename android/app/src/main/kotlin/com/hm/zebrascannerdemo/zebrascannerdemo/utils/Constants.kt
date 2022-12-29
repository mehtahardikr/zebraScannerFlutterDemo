package com.hm.zebrascannerdemo.zebrascannerdemo.utils

object Constants {

    const val CHANNEL = "com.hm.zebra/scanner"
    const val EVENT_CHANNEL = "com.hm.zebra/scannerEvents"
    const val EVENT_CHANNEL_BARCODE = "com.hm.zebra/barcodeEvents"

    //Type of data recieved
    const val BARCODE_RECEIVED = 30

    /// events
    const val EVENT_INIT = "init"
    const val EVENT_PAIR = "pair"
    const val EVENT_TEST_BEEP = "testBeep"
    const val EVENT_DISCONNECT = "disconnect"
    const val EVENT_GET_LIST = "getList"
    const val EVENT_ACTIVE_SCANNER_LIST = "getActiveScannerList"
}

