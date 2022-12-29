package com.hm.zebrascannerdemo.zebrascannerdemo.adapter

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.annotation.NonNull
import androidx.appcompat.widget.AppCompatTextView
import androidx.recyclerview.widget.RecyclerView
import com.hm.zebrascannerdemo.zebrascannerdemo.R
import com.zebra.scannercontrol.DCSScannerInfo

class ScannerDataAdapter(
    private val mDataset: MutableList<DCSScannerInfo>,
    var recyclerViewItemClickListener: RecyclerViewItemClickListener) :
    RecyclerView.Adapter<ScannerDataAdapter.DataViewHolder>() {
    @NonNull
    override fun onCreateViewHolder(
        @NonNull parent: ViewGroup,
        i: Int
    ): DataViewHolder {
        val v: View =
            LayoutInflater.from(parent.getContext()).inflate(R.layout.row_item, parent, false)
        return DataViewHolder(v)
    }

    override fun onBindViewHolder(@NonNull dataViewHolder: DataViewHolder, i: Int) {
        dataViewHolder.mTextView.setText(mDataset[i].scannerName)
    }

    override fun getItemCount(): Int {
        return mDataset.size
    }

    inner class DataViewHolder(v: View) : RecyclerView.ViewHolder(v), View.OnClickListener {
        var mTextView: AppCompatTextView

        init {
            mTextView = v.findViewById(R.id.tvName) as AppCompatTextView
            v.setOnClickListener(this)
        }

        override fun onClick(v: View?) {
            recyclerViewItemClickListener.clickOnItem(mDataset[this.adapterPosition].scannerID)
        }
    }

    interface RecyclerViewItemClickListener {
        fun clickOnItem(data: Int?)
    }
}
