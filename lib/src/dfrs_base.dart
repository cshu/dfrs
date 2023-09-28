import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:async/async.dart';
//import 'package:collection/collection.dart';
//import 'package:path/path.dart' as path;
import 'package:typed_data/typed_data.dart';


void debugAssert(bool debugCondition){
	if(!debugCondition) throw CommonException('debugAssert failed');
}

class CommonException implements Exception {
  final String message;
  const CommonException(this.message);
  String toString() => 'CommonException: ' + message;
}

Future<Uint8List> fetchBytesIntoBufferWithLenLE(StreamQueue<Uint8List> sk, Uint8Buffer availDataBuffer, Uint8Buffer rest) async {
	Uint8Buffer temRest = new Uint8Buffer();
	Uint8List lenBytes = await fetchBytesIntoBuffer(sk, 4, availDataBuffer, temRest);
	int len = ByteData.sublistView(lenBytes).getUint32(0, Endian.little);
	//int len = availDataBuffer.buffer.asByteData().getUint32(0, Endian.little);
	return await fetchBytesIntoBuffer(sk, len, temRest, rest);
}

/**
*note the return value is a view of availDataBuffer
*availDataBuffer may end up with more data than lenNeeded
*rest actually contains data that equals the extra part at the end of availDataBuffer
*/
Future<Uint8List> fetchBytesIntoBuffer(StreamQueue<Uint8List> sk, int lenNeeded,
    Uint8Buffer availDataBuffer, Uint8Buffer rest) async {
  for (;;) {
    if (availDataBuffer.length >= lenNeeded) {
      rest.addAll(availDataBuffer.buffer
          .asUint8List(lenNeeded));
      return availDataBuffer.buffer.asUint8List(0, lenNeeded);
    }
    var first = await sk.next;
    availDataBuffer.addAll(first);
  }
}

/**
*see fetchBytesIntoBuffer
*/
Future<Uint8List> fetchBytesIntoBufferUntilNul(StreamQueue<Uint8List> sk,
    Uint8Buffer availDataBuffer, Uint8Buffer rest) async {
  for (int searchIndex = 0;;) {
    int nulIndex = availDataBuffer.indexOf(0, searchIndex);
    if (nulIndex!=-1) {
      rest.addAll(availDataBuffer.buffer
          .asUint8List(nulIndex+1));
      return availDataBuffer.buffer.asUint8List(0, nulIndex);
    }
    searchIndex = availDataBuffer.length;
    var first = await sk.next;
    availDataBuffer.addAll(first);
  }
}

Future<String> fetchNulTermStr(StreamQueue<Uint8List> sk, Uint8Buffer availDataBuffer, Uint8Buffer rest) async {
	Uint8List strBytes = await fetchBytesIntoBufferUntilNul(sk, availDataBuffer, rest);
	return utf8.decode(strBytes);
}

Future<String> fetchStrWithLenLE(StreamQueue<Uint8List> sk, Uint8Buffer availDataBuffer, Uint8Buffer rest) async {
	Uint8List strBytes = await fetchBytesIntoBufferWithLenLE(sk, availDataBuffer, rest);
	return utf8.decode(strBytes);
}

Future<Uint8List> fetchBytesIntoBufferWithLenUint8(StreamQueue<Uint8List> sk, Uint8Buffer availDataBuffer, Uint8Buffer rest) async {
	Uint8Buffer temRest = new Uint8Buffer();
	Uint8List lenBytes = await fetchBytesIntoBuffer(sk, 1, availDataBuffer, temRest);
	return await fetchBytesIntoBuffer(sk, lenBytes.first, temRest, rest);
}

Future<String> fetchStrWithLenUint8(StreamQueue<Uint8List> sk, Uint8Buffer availDataBuffer, Uint8Buffer rest) async {
	Uint8List strBytes = await fetchBytesIntoBufferWithLenUint8(sk, availDataBuffer, rest);
	return utf8.decode(strBytes);
}

void writeStrToIOSinkWithLenLE(IOSink sink, String str){
	List<int> strBytes = utf8.encode(str);
	writeInt32leToIOSink(sink, strBytes.length);
	sink.add(strBytes);
}
void writeInt32leToIOSink(IOSink sink, int intVal){
	ByteData integerBytes = ByteData(4)..setUint32(0, intVal, Endian.little);
	sink.add(Uint8List.sublistView(integerBytes));
}

class BufferForFetchingBytesFromStreamQueue{
	Uint8Buffer availDataBuffer=Uint8Buffer();
	Uint8Buffer restDataBuffer=Uint8Buffer();
	final StreamQueue<Uint8List> sk;
	BufferForFetchingBytesFromStreamQueue(Stream<Uint8List> src):sk = StreamQueue<Uint8List>(src){
	}
	
	//release memory
	void treatRestBufferAsAvailDataAndNewRestBuffer(){
		availDataBuffer = restDataBuffer;
		restDataBuffer = Uint8Buffer();
	}
	Future<Uint8List> fetchBytes(int lenNeeded) async {
		Uint8List retval = await fetchBytesIntoBuffer(sk, lenNeeded, availDataBuffer, restDataBuffer);
		treatRestBufferAsAvailDataAndNewRestBuffer();
		return retval;
	}
	Future<String> fetchStrWithLenLE() async {
		Uint8List retval = await fetchBytesIntoBufferWithLenLE(sk, availDataBuffer, restDataBuffer);
		treatRestBufferAsAvailDataAndNewRestBuffer();
		return utf8.decode(retval);
	}
	Future<Uint8List> fetchBytesWithLenLE() async {
		Uint8List retval = await fetchBytesIntoBufferWithLenLE(sk, availDataBuffer, restDataBuffer);
		treatRestBufferAsAvailDataAndNewRestBuffer();
		return retval;
	}
	Future<String> fetchNulTerminatedStr()async{
		String retval = await fetchNulTermStr(sk, availDataBuffer, restDataBuffer);
		treatRestBufferAsAvailDataAndNewRestBuffer();
		return retval;
	}
	Future<int> fetchUint32LE()async{
		return ByteData.sublistView(await fetchBytes(4)).getUint32(0, Endian.little);
	}
	Future<List<Uint8List>> fetchBlobsWithLenLE() async {
		int count = await fetchUint32LE();
		List<Uint8List> retval = List<Uint8List>.filled(count, Uint8List(0));
		for(int ind = 0;ind<count;++ind){
			retval[ind] = await fetchBytesWithLenLE();
		}
		return retval;
	}
	Future<int> fetchUint64LE()async{
		return ByteData.sublistView(await fetchBytes(8)).getUint64(0, Endian.little);
	}
	Future<int> fetchInt64LE()async{
		return ByteData.sublistView(await fetchBytes(8)).getInt64(0, Endian.little);
	}
	Future<int?> fetchInt64leIfAvail()async{
		if(0==(await fetchBytes(1)).first) return null;
		return await fetchInt64LE();
	}
	Future<Uint8List?> fetchBytesIfAvail(int lenNeeded)async{
		if(0==(await fetchBytes(1)).first) return null;
		return await fetchBytes(lenNeeded);
	}
}
