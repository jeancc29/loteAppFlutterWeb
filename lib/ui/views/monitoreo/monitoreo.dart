import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loterias/core/classes/database.dart';
import 'package:loterias/core/classes/monitoreo.dart';
import 'package:loterias/core/classes/utils.dart';
import 'package:loterias/core/models/bancas.dart';
import 'package:loterias/core/models/ventas.dart';
import 'package:loterias/core/services/bancaservice.dart';
import 'package:loterias/core/services/bluetoothchannel.dart';
import 'package:loterias/core/services/ticketservice.dart';
import 'package:rxdart/rxdart.dart';

class MonitoreoScreen extends StatefulWidget {
  @override
  _MonitoreoScreenState createState() => _MonitoreoScreenState();
}

class _MonitoreoScreenState extends State<MonitoreoScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime _fecha = DateTime.now();
  List<Banca> _bancas;
  Future<bool> listaBancaFuture;
  StreamController<bool> _streamControllerMonitoreo;
  bool _tienePermisoMonitoreo = false;
  bool _tienePermisoJugarComoCualquierBanca = false;
  bool _tienePermisoCancelarCualquierMomento = false;
  bool _cargando = false;
  int _indexBanca = 0;
  List<Venta> _listaVenta;
  List<Venta> _tmpListaVenta;
  Banca _banca;
  @override
  initState() {
    // TODO: implement initState
    _getBanca();
    listaBancaFuture = _futureBancas();
  _confirmarTienePermiso();
  _getMonitoreo();
  _streamControllerMonitoreo = BehaviorSubject();
    super.initState();
  }

  @override
  dispose(){
    super.dispose();
  }

  _getBanca() async {
    _banca = Banca.fromMap(await Db.getBanca());
  }

  Future<bool> _futureBancas() async{
    _bancas = await BancaService.all(scaffoldKey: _scaffoldKey);
    _seleccionarBancaPertenecienteAUsuario();
    return true;
  }

  _confirmarTienePermiso() async {
   _tienePermisoMonitoreo = await Db.existePermiso("Monitorear ticket");
   _tienePermisoJugarComoCualquierBanca = await Db.existePermiso("Jugar como cualquier banca");
   _tienePermisoCancelarCualquierMomento = await Db.existePermiso("Cancelar tickets en cualquier momento");
  }

  _getMonitoreo() async {
   try{
     setState(() => _cargando = true);
    _listaVenta = await TicketService.monitoreo(scaffoldKey: _scaffoldKey, fecha: _fecha.toString(), idBanca: (_tienePermisoJugarComoCualquierBanca && _bancas != null) ? _bancas[_indexBanca].id : await Db.idBanca());
    _tmpListaVenta = _listaVenta.map((v) => v).toList();;
    _streamControllerMonitoreo.add(true);
    setState(() => _cargando = false);
   } on Exception catch(e){
      setState(() => _cargando = false);
   }
  }

  _seleccionarBancaPertenecienteAUsuario() async {
  var bancaMap = await Db.getBanca();
  Banca banca = (bancaMap != null) ? Banca.fromMap(bancaMap) : null;
  if(banca != null && _bancas != null){
    int idx = _bancas.indexWhere((b) => b.id == banca.id);
    // print('_seleccionarBancaPertenecienteAUsuario idx: $idx : ${_bancas.length}');
    setState(() => _indexBanca = (idx != -1) ? idx : 0);
  }else{
    setState(() =>_indexBanca = 0);
  }

  // print('seleccionarBancaPerteneciente: $_indexBanca : ${banca.descripcion} : ${_bancas.length}');
}

  Widget _buildTable(List<Venta> ventas, Banca banca){
   var tam = ventas.length;
   List<TableRow> rows;
   if(tam == 0){
     rows = <TableRow>[];
   }else{
     rows = ventas.map((v)
          => TableRow(
            children: [
              Center(
                child: InkWell(onTap: (){Monitoreo.showDialogImprimirCompartir(venta: v, context: context);}, child: Text(Utils.toSecuencia(banca.codigo, v.idTicket, false), style: TextStyle(fontSize: 16, decoration: TextDecoration.underline)))
              ),
              Center(child: Text(v.total.toString(), style: TextStyle(fontSize: 16))),
              Center(child: IconButton(icon: Icon(Icons.delete, size: 28,), onPressed: () async {
                bool cancelar = await TicketService.showDialogAceptaCancelar(context: context, ticket: Utils.toSecuencia(banca.codigo, v.idTicket, false));
                if(cancelar){
                  if(_tienePermisoCancelarCualquierMomento){
                    bool imprimir = await TicketService.showDialogDeseaImprimir(context: context);
                    if(imprimir){
                       if(await Utils.exiseImpresora() == false){
                        Utils.showSnackBar(scaffoldKey: _scaffoldKey, content: "Debe registrar una impresora");
                        return;
                      }

                      if(!(await BluetoothChannel.turnOn())){
                        return;
                      }

                      try{
                        setState(() => _cargando = true);
                        var datos = await TicketService.cancelar(scaffoldKey: _scaffoldKey, codigoBarra: v.codigoBarra);
                        await BluetoothChannel.printTicket(datos["ticket"], BluetoothChannel.TYPE_CANCELADO);
                        setState(() => _cargando = false);
                        Utils.showSnackBar(scaffoldKey: _scaffoldKey, content: datos["mensaje"]);
                      } on Exception catch(e){
                        setState(() => _cargando = false);
                      }
                    }else{
                      try{
                        setState(() => _cargando = true);
                        var datos = await TicketService.cancelar(scaffoldKey: _scaffoldKey, codigoBarra: v.codigoBarra);
                        setState(() => _cargando = false);
                        Utils.showSnackBar(scaffoldKey: _scaffoldKey, content: datos["mensaje"]);
                      }on Exception catch(e){
                        setState(() => _cargando = false);
                      }
                    }
                  }else{

                    if(await Utils.exiseImpresora() == false){
                      Utils.showSnackBar(scaffoldKey: _scaffoldKey, content: "Debe registrar una impresora");
                      return;
                    }

                    if(!(await BluetoothChannel.turnOn())){
                      return;
                    }
                    try{
                      setState(() => _cargando = true);
                      var datos = await TicketService.cancelar(scaffoldKey: _scaffoldKey, codigoBarra: v.codigoBarra);
                      setState(() => _cargando = false);
                      await BluetoothChannel.printTicket(datos["ticket"], BluetoothChannel.TYPE_CANCELADO);
                      Utils.showSnackBar(scaffoldKey: _scaffoldKey, content: datos["mensaje"]);
                    } on Exception catch(e){
                      setState(() => _cargando = false);
                    }
                  }
                  await _getMonitoreo();
                }
              },)),
            ],
          )
        
        ).toList();
        
    rows.insert(0, 
              TableRow(
                decoration: BoxDecoration(color: Utils.colorPrimary),
                children: [
                  // buildContainer(Colors.blue, 50.0),
                  // buildContainer(Colors.red, 50.0),
                  // buildContainer(Colors.blue, 50.0),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: Text('Ticket', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: Text('Monto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: Text('Borrar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),),
                  ),
                ]
              )
              );
        
   }

   return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: <int, TableColumnWidth>{0 : FractionColumnWidth(.35)},
              children: rows,
             ),
        );

  return Flexible(
      child: ListView(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: <int, TableColumnWidth>{0 : FractionColumnWidth(.35)},
              children: rows,
             ),
        ),
      ],
    ),
  );
  
 }

 

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      key: _scaffoldKey,
        appBar: AppBar(
          leading: BackButton(
            color: Utils.colorPrimary,
          ),
          title: Text("Monitoreo", style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: <Widget>[
             Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Visibility(
                        visible: _cargando,
                        child: Theme(
                          data: Theme.of(context).copyWith(accentColor: Utils.colorPrimary),
                          child: new CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Visibility(
                    visible: _tienePermisoJugarComoCualquierBanca,
                    child: Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FutureBuilder<bool>(
                          future: listaBancaFuture,
                          builder: (context, snapshot){
                            // print("FutureBuilder: ${snapshot.connectionState}");
                            if(snapshot.hasData){
                              
                              // _bancas = snapshot.data;
                              return DropdownButton(
                                hint: Text("Sel. banca"),
                                // isExpanded: true,
                                value: _bancas[_indexBanca],
                                onChanged: (Banca banca) async {
                                  int idx = _bancas.indexWhere((b) => b.id == banca.id);
                                  setState(() => _indexBanca = (idx != -1) ? idx : 0);
                                  // print("banca: ${banca.descripcion}");
                                  _getMonitoreo();
                                },
                                items: _bancas.map((b) => DropdownMenuItem<Banca>(
                                  value: b,
                                  child: Text("${b.descripcion}"),
                                )).toList(),
                              );
                            }
                            return DropdownButton(
                              value: "No hay bancas",
                              onChanged: (String data){},
                              items: [DropdownMenuItem(value: "No hay bancas", child: Text("No hay bancas"),)],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: RaisedButton(
                        child: Text("${_fecha.year}-${_fecha.month}-${_fecha.day}"), 
                        color: Colors.transparent, 
                        onPressed: () async {
                          var fecha = await showDatePicker( context: context, initialDate: DateTime.now(), firstDate: DateTime(2001), lastDate: DateTime(2022));
                          setState(() => _fecha = (fecha != null) ? fecha : _fecha);
                          await _getMonitoreo();
                          // showModalBottomSheet(
                          //   context: context, 
                            
                          //   builder: (context){
                          //     return Container(
                          //       height: MediaQuery.of(context).size.height / 3,
                          //       child: CupertinoDatePicker(
                          //         initialDateTime: DateTime.now(),
                          //         mode: CupertinoDatePickerMode.date,
                          //         minuteInterval: 1,
                          //         onDateTimeChanged: (fecha){
                          //           setState(() => _fecha = fecha);
                          //         }
                          //       ),
                          //     );
                          //   }
                          // );
                          // showDialog(
                          //   context: context,
                          //   builder: (context){
                          //     return AlertDialog(
                          //       title: Text("Seleccionar fecha"),
                          //       content: Container(
                          //       height: MediaQuery.of(context).size.height / 3,
                                
                          //       child: SizedBox(
                          //         width: MediaQuery.of(context).size.width - 100,
                          //         child: CupertinoDatePicker(
                          //           initialDateTime: DateTime.now(),
                          //           mode: CupertinoDatePickerMode.date,
                          //           minuteInterval: 1,

                          //           onDateTimeChanged: (fecha){
                          //             setState(() => _fecha = fecha);
                          //           }
                          //         ),
                          //       ),
                          //     ),
                          //     );
                          //   }
                          // );
                        }, 
                        elevation: 0, shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey, width: 1)),),
                    )
                  )
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(hintText: "Numero ticket"),
                  onChanged: (String text){
                    print("TextField chagned: $text");
                    if(text.isEmpty)
                      _listaVenta = _tmpListaVenta;
                    else
                      _listaVenta = _tmpListaVenta.where((v) => v.idTicket.toString().indexOf(text) != -1).toList();
                    
                    _streamControllerMonitoreo.add(true);  
                  },
                ),
              ),
              StreamBuilder<bool>(
                stream: _streamControllerMonitoreo.stream,
                builder: (context, snapshot){
                  // print("${snapshot.hasData}");
                  if(snapshot.hasData){
                    return _buildTable(_listaVenta.where((v) => v.status != 0 && v.status != 5).toList(), (_tienePermisoMonitoreo && _bancas != null) ? _bancas[_indexBanca] : _banca);
                  }
                  return _buildTable(List<Venta>(), null);
                },
              )
            ],
          ),
        ),
      );
    
  }
}