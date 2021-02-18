import 'dart:async';

import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/chat/Message.dart';
import 'package:xmpp_stone/src/data/Jid.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/AbstractStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/MessageStanza.dart';
import 'Message.dart';

class ChatImpl implements Chat {

  static String TAG = 'Chat';

  final Connection _connection;
  final Jid _jid;

  @override
  Jid get jid => _jid;
  ChatState _myState;
  @override
  ChatState get myState => _myState;

  ChatState _remoteState;
  @override
  ChatState get remoteState => _remoteState;

  @override
  List<Message> messages = [];

  final StreamController<Message> _newMessageController =
      StreamController.broadcast();
  final StreamController<ChatState> _remoteStateController =
      StreamController.broadcast();

  @override
  Stream<Message> get newMessageStream => _newMessageController.stream;
  @override
  Stream<ChatState> get remoteStateStream => _remoteStateController.stream;

  ChatImpl(this._jid, this._connection);

  void parseMessage(Message message) {
    if (message.type == MessageStanzaType.CHAT) {
      if (message.text != null && message.text.isNotEmpty) {
        messages.add(message);
        _newMessageController.add(message);
      }

      if (message?.chatState != null && !(message?.isDelayed ?? false)) {
        _remoteState = message.chatState;
        _remoteStateController.add(message.chatState);
      }
    }
  }

  @override
  void sendMessage(String text) {
    var stanza = MessageStanza(AbstractStanza.getRandomId(), MessageStanzaType.CHAT);
    stanza.toJid = _jid;
    stanza.fromJid = _connection.fullJid;
    stanza.body = text;
    var message = Message.fromStanza(stanza);
    messages.add(message);
    _newMessageController.add(message);
    _connection.writeStanza(stanza);
  }

  // https://stackoverflow.com/questions/57095305/how-to-edit-and-delete-particular-message-from-xmpp-in-android
  
  //<message to='juliet@capulet.net/balcony' id='good1'>
  //   <body>But soft, what light through yonder window breaks?</body>
  //   <replace id='bad1' xmlns='urn:xmpp:message-correct:0'/>
  // </message>
  
  @override
  void updateMessage(String id, String text) {
    var stanza = MessageStanza(AbstractStanza.getRandomId(), MessageStanzaType.CHAT);
    stanza.toJid = _jid;
    stanza.fromJid = _connection.fullJid;
    stanza.body = text;

    var stateElement = XmppElement();
    stateElement.name = 'replace';
    stateElement.addAttribute(XmppAttribute('id', id));
    stateElement.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:message-correct:0'));
    stanza.addChild(stateElement);

    var message = Message.fromStanza(stanza);
    int lastIndex = messages.indexWhere((element) => element?.messageStanza?.id == id);
    messages[lastIndex] = message;
    _newMessageController.add(message);
    _connection.writeStanza(stanza);
  }

  //<message to='room@muc.example.com' id='remove1'>
  //   <remove id='bad1' xmlns='urn:xmpp:message-delete:0'/>
  // </message>

  @override
  void deleteMessage(String id) {
    var stanza =
    MessageStanza(AbstractStanza.getRandomId(), MessageStanzaType.CHAT);
    stanza.toJid = _jid;
    stanza.fromJid = _connection.fullJid;

    var stateElement = XmppElement();
    stateElement.name = 'remove';
    stateElement.addAttribute(XmppAttribute('id', id));
    stateElement.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:message-delete:0'));
    stanza.addChild(stateElement);

    var message = Message.fromStanza(stanza);
    messages.remove(message);
    _newMessageController.add(message);

    _connection.writeStanza(stanza);
  }

  //<message
  //     from='bernardo@shakespeare.lit/pda'
  //     to='francisco@shakespeare.lit'
  //     type='chat'>
  //   <body>Who's there?</body>
  //   <active xmlns='http://jabber.org/protocol/chatstates'/>
  // </message>

  @override
  set myState(ChatState state) {
    var stanza = MessageStanza(AbstractStanza.getRandomId(), MessageStanzaType.CHAT);
    stanza.toJid = _jid;
    stanza.fromJid = _connection.fullJid;
    var stateElement = XmppElement();
    stateElement.name = state.toString().split('.').last.toLowerCase();
    stateElement.addAttribute(XmppAttribute('xmlns', 'http://jabber.org/protocol/chatstates'));
    stanza.addChild(stateElement);
    _connection.writeStanza(stanza);
    _myState = state;
  }
}

abstract class Chat {
  Jid get jid;
  ChatState get myState;
  ChatState get remoteState;
  Stream<Message> get newMessageStream;
  Stream<ChatState> get remoteStateStream;
  List<Message> messages;
  void sendMessage(String text);
  void updateMessage(String id, String text);
  void deleteMessage(String id);
  set myState(ChatState state);
}

enum ChatState { INACTIVE, ACTIVE, GONE, COMPOSING, PAUSED }
