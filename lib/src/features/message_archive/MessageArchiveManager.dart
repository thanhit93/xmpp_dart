import 'package:xmpp_stone/src/elements/forms/QueryElement.dart';
import 'package:xmpp_stone/src/elements/forms/XElement.dart';
import 'package:xmpp_stone/src/features/servicediscovery/MAMNegotiator.dart';
import '../../Connection.dart';
import '../../data/Jid.dart';
import '../../elements/stanzas/AbstractStanza.dart';
import '../../elements/stanzas/IqStanza.dart';
import '../../elements/forms/FieldElement.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import '../../logger/Log.dart';
import 'package:tuple/tuple.dart';
import 'dart:async';

class MessageArchiveManager {
  static const TAG = 'MessageArchiveManager';

  static final Map<Connection, MessageArchiveManager> _instances =
      <Connection, MessageArchiveManager>{};

  static MessageArchiveManager getInstance(Connection connection) {
    var instance = _instances[connection];
    if (instance == null) {
      instance = MessageArchiveManager(connection);
      _instances[connection] = instance;
    }
    return instance;
  }

  final Connection _connection;

  bool get enabled => MAMNegotiator.getInstance(_connection).enabled;

  bool get hasExtended => MAMNegotiator.getInstance(_connection).hasExtended;

  bool get isQueryByDateSupported => MAMNegotiator.getInstance(_connection).isQueryByDateSupported;

  bool get isQueryByIdSupported => MAMNegotiator.getInstance(_connection).isQueryByIdSupported;

  bool get isQueryByJidSupported => MAMNegotiator.getInstance(_connection).isQueryByJidSupported;

  final Map<String, Tuple2<IqStanza, Completer>> _myUnrespondedIqStanzas =
  <String, Tuple2<IqStanza, Completer>>{};

  MessageArchiveManager(this._connection) {
    _connection.inStanzasStream.listen(_processStanza);
  }

  void queryAll() {
    var iqStanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
    var query = QueryElement();
    query.setXmlns('urn:xmpp:mam:2');
    query.setQueryId(AbstractStanza.getRandomId());
    iqStanza.addChild(query);
    _connection.writeStanza(iqStanza);
  }

  void queryByTime({DateTime start, DateTime end, Jid jid}) {
    if (start == null && end == null && jid == null) {
      queryAll();
    } else {
      var iqStanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
      var query = QueryElement();
      query.setXmlns('urn:xmpp:mam:2');
      query.setQueryId(AbstractStanza.getRandomId());
      iqStanza.addChild(query);
      var x = XElement.build();
      x.setType(FormType.SUBMIT);
      query.addChild(x);
      x.addField(FieldElement.build(
          varAttr: 'FORM_TYPE', typeAttr: 'hidden', value: 'urn:xmpp:mam:2'));
      if (start != null) {
        x.addField(
            FieldElement.build(varAttr: 'start', value: start.toIso8601String()));
      }
      if (end != null) {
        x.addField(FieldElement.build(varAttr: 'end', value: end.toIso8601String()));
      }
      if (jid != null) {
        x.addField(FieldElement.build(varAttr: 'with', value: jid.userAtDomain));
      }
      _connection.writeStanza(iqStanza);
    }
  }

  void queryById({String beforeId, String afterId, Jid jid}) {
    if (beforeId == null && afterId == null && jid == null) {
      queryAll();
    } else {
      var iqStanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
      var query = QueryElement();
      query.setXmlns('urn:xmpp:mam:2');
      query.setQueryId(AbstractStanza.getRandomId());
      iqStanza.addChild(query);
      var x = XElement.build();
      x.setType(FormType.SUBMIT);
      query.addChild(x);
      x.addField(FieldElement.build(
          varAttr: 'FORM_TYPE', typeAttr: 'hidden', value: 'urn:xmpp:mam:2'));
      if (beforeId != null) {
        x.addField(FieldElement.build(varAttr: 'beforeId', value: beforeId));
      }
      if (afterId != null) {
        x.addField(FieldElement.build(varAttr: 'afterId', value: afterId));
      }
      if (jid != null) {
        x.addField(FieldElement.build(varAttr: 'with', value: jid.userAtDomain));
      }

      //<iq type='set' id='q29302'>
    //   <query xmlns='urn:xmpp:mam:0'>
    //     <x xmlns='jabber:x:data' type='submit'>
    //       <field var='FORM_TYPE' type='hidden'>
    //         <value>urn:xmpp:mam:0</value>
    //       </field>
    //       <field var='with'>
    //         <value>juliet@capulet.lit</value>
    //       </field>
    //     </x>
    //     <set xmlns='http://jabber.org/protocol/rsm'>
    //      <max>20</max>
    //      <before/>
    //     </set>
    //   </query>
    // </iq>

      var set = XmppElement();
      set.name = 'set';
      set.addAttribute(XmppAttribute('xmlns', 'http://jabber.org/protocol/rsm'));

      var max = XmppElement();
      max.name = 'max';
      max.textValue = '20';
      set.addChild(max);

      var before = XmppElement();
      before.name = 'before';
      set.addChild(before);

      query.addChild(set);

      _connection.writeStanza(iqStanza);
    }
  }

  // void fetchHistoryChat(Jid fromJid, Jid toJid,) {
  //   //<iq id='a5sV8-21' type='set'>
  //   //     <query xmlns='urn:xmpp:mam:0' queryid="12345678">
  //   //         <x xmlns="jabber:x:data" type="submit">
  //   //             <field var="FORM_TYPE" type="hidden"><value>urn:xmpp:mam:0</value></field>
  //   //             <field var="with"><value>id@domain</value></field>
  //   //         </x>
  //   //         <set xmlns="http://jabber.org/protocol/rsm">
  //   //             <max>message_count</max>
  //   //         </set>
  //   //     </query>
  //   // </iq>
  //
  //   var iqStanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
  //   iqStanza.fromJid = fromJid;
  //   iqStanza.toJid = toJid;
  //  
  //   var query = QueryElement();
  //   query.setXmlns('urn:xmpp:mam:2');
  //   query.setQueryId(AbstractStanza.getRandomId());
  //   iqStanza.addChild(query);
  //   var x = XElement.build();
  //   x.setType(FormType.SUBMIT);
  //   query.addChild(x);
  //   x.addField(FieldElement.build(
  //       varAttr: 'FORM_TYPE', typeAttr: 'hidden', value: 'urn:xmpp:mam:2'));
  //   if (jid != null) {
  //     x.addField(FieldElement.build(varAttr: 'with', value: jid.userAtDomain));
  //   }
  //   var set = XmppElement();
  //   set.name = 'set';
  //   set.addAttribute(XmppAttribute('xmlns', 'http://jabber.org/protocol/rsm'));
  //
  //   var max = XmppElement();
  //   max.name = 'max';
  //   max.textValue = '100';
  //   set.addChild(max);
  //
  //   query.addChild(set);
  //
  //   _connection.writeStanza(iqStanza);
  // }

  //https://xmpp.org/extensions/xep-0136.html
  Future<bool> fetchLastMessage(Jid jid) {
    // <iq type='get' id='page1'>
    // <retrieve xmlns='urn:xmpp:archive'
    // with='juliet@capulet.com/chamber'
    // start='1469-07-21T02:56:15Z'>
    // <set xmlns='http://jabber.org/protocol/rsm'>
    // <max>100</max>
    // </set>
    // </retrieve>
    // </iq>
    var completer = Completer<bool>();
    var iqStanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.GET);
    iqStanza.fromJid = _connection.fullJid;
    iqStanza.toFullJid = jid;
    var retrieve = XmppElement();
    retrieve.name = 'retrieve';
    retrieve.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:archive'));
    retrieve.addAttribute(XmppAttribute('with', jid.fullJid));
    retrieve.addAttribute(XmppAttribute('start', '2020-01-21T02:56:15Z'));

    var set = XmppElement();
    set.name = 'set';
    set.addAttribute(XmppAttribute('xmlns', 'http://jabber.org/protocol/rsm'));

    var max = XmppElement();
    max.name = 'max';
    max.textValue = '100';
    set.addChild(max);

    retrieve.addChild(set);

    iqStanza.addChild(retrieve);
    _myUnrespondedIqStanzas[iqStanza.id] = Tuple2(iqStanza, completer);
    _connection.writeStanza(iqStanza);

    return completer.future;
  }

  void _processStanza(AbstractStanza stanza) {
    // Log.xmppp_receiving('start log MAM Thanh test');
    // Log.xmppp_receiving(stanza.buildXmlString());
    // Log.xmppp_receiving('end log MAM Thanh test');
    if (stanza is IqStanza) {
      var unrespondedStanza = _myUnrespondedIqStanzas[stanza.id];
      if (_myUnrespondedIqStanzas[stanza.id] != null) {
        if (stanza.type == IqStanzaType.RESULT) {
          unrespondedStanza.item2.complete(true);
        }
      }
    }
  }
}

//method for getting module
extension MamModuleGetter on Connection {
  MessageArchiveManager getMamModule() {
    return MessageArchiveManager.getInstance(this);
  }
}
