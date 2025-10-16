import 'package:cloud_firestore/cloud_firestore.dart';
enum ChatSystemEvent {
  leadAssigned,
  leadUnassigned,
  registrationCompleted,
  installationCompleted,
}


enum MessageType {
  text,
    video,  // Add this

  image,
  pdf,
  voice,
  lead,
}

class ChatMember {
  final String uid;
  final String name;
  final String email;
  final DateTime joinedAt;

  ChatMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.joinedAt,
  });

  factory ChatMember.fromMap(Map<String, dynamic> map) {
    return ChatMember(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}

// lib/models/chat_models.dart  (only the ChatGroup parts shown)

class ChatGroup {
  final String id;
  final String name;
  final String description;

  /// NEW: multiple districts
  final List<String> districts;

  /// keep state as single (you can upsize later if needed)
  final String state;

  /// DEPRECATED: keep reading & writing for compatibility
  final String workLocation;

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMember> members;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? groupIcon;

  ChatGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.districts,
    required this.state,
    required this.workLocation, // legacy single location
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
    this.lastMessage,
    this.lastMessageTime,
    this.groupIcon,
  });

  factory ChatGroup.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});

    // members
    final membersList = (data['members'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMember.fromMap)
        .toList();

    // districts (new) with fallback to legacy 'workLocation'
    final List<String> districts = (data['districts'] as List?)
            ?.whereType<String>()
            .toList() ??
        (data['workLocation'] != null && (data['workLocation'] as String).trim().isNotEmpty
            ? <String>[(data['workLocation'] as String).trim()]
            : <String>[]);

    return ChatGroup(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      districts: districts,
      state: (data['state'] ?? '').toString(),
      workLocation: (data['workLocation'] ?? '').toString(), // keep it
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      members: membersList,
      lastMessage: data['lastMessage'] as String?,
      lastMessageTime: (data['lastMessageTime'] is Timestamp)
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      groupIcon: data['groupIcon'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,

      // write both for compatibility
      'districts': districts,
      'workLocation': districts.isNotEmpty ? districts.first : workLocation,

      'state': state,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'members': members.map((m) => m.toMap()).toList(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'groupIcon': groupIcon,
    };
  }

  ChatGroup copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? districts,
    String? state,
    String? workLocation,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMember>? members,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? groupIcon,
  }) {
    return ChatGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      districts: districts ?? this.districts,
      state: state ?? this.state,
      workLocation: workLocation ?? this.workLocation,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      groupIcon: groupIcon ?? this.groupIcon,
    );
  }

  int get memberCount => members.length;

  /// show “District1, District2 – State”
  String get locationDisplay {
    final d = districts.where((e) => e.trim().isNotEmpty).toList();
    final left = d.isEmpty ? (workLocation.isNotEmpty ? workLocation : '-') : d.join(', ');
    final s = state.trim().isEmpty ? '-' : state;
    return '$left, $s';
  }
}

class ChatMessage {
  final String id;
    final List<String>? readBy;

  final String groupId;
  final String senderId;
  final String senderName;
  final String senderEmail;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final String? fileUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final String? leadId;
  final String? leadName;
  final int? voiceDurationSeconds;
  final bool isRead;
  final String? thumbnailUrl;  // Add this for video thumbnails
  final int? videoDurationSeconds;  // Add this for video duration

  ChatMessage({
    required this.id,
        this.thumbnailUrl,
            this.readBy,

    this.videoDurationSeconds,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.type,
    required this.content,
    required this.timestamp,
    this.fileUrl,
    this.fileName,
    this.fileSizeBytes,
    this.leadId,
    this.leadName,
    this.voiceDurationSeconds,
    this.isRead = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    MessageType messageType = MessageType.text;
    String typeStr = data['type'] ?? 'text';
    switch (typeStr) {
      case 'image':
        messageType = MessageType.image;
        break;
      case 'pdf':
        messageType = MessageType.pdf;
        break;
      case 'voice':
        messageType = MessageType.voice;
      
        break;
              case 'video':  // Add this
        messageType = MessageType.video;
        break;
      case 'lead':
        messageType = MessageType.lead;
        break;
      default:
        messageType = MessageType.text;
    }

    return ChatMessage(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      type: messageType,
      thumbnailUrl: data['thumbnailUrl'],
      videoDurationSeconds: data['videoDurationSeconds'],
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      fileSizeBytes: data['fileSizeBytes'],
      leadId: data['leadId'],
         readBy: data['readBy'] != null 
          ? List<String>.from(data['readBy']) 
          : null,
      leadName: data['leadName'],
      voiceDurationSeconds: data['voiceDurationSeconds'],
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
            'thumbnailUrl': thumbnailUrl,
      'videoDurationSeconds': videoDurationSeconds,
      'senderId': senderId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'type': type.name,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'leadId': leadId,
            'readBy': readBy,

      'leadName': leadName,
      'voiceDurationSeconds': voiceDurationSeconds,
      'isRead': isRead,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? senderEmail,
    MessageType? type,
    String? content,
    DateTime? timestamp,
    String? fileUrl,
    String? fileName,
    int? fileSizeBytes,
    String? leadId,
    String? leadName,
    int? voiceDurationSeconds,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      leadId: leadId ?? this.leadId,
      leadName: leadName ?? this.leadName,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      isRead: isRead ?? this.isRead,
    );
  }

  bool get isTextMessage => type == MessageType.text;
  bool get isImageMessage => type == MessageType.image;
  bool get isPdfMessage => type == MessageType.pdf;
  bool get isVoiceMessage => type == MessageType.voice;
  bool get isLeadMessage => type == MessageType.lead;
  bool get isVideoMessage => type == MessageType.video;

  String get fileSizeFormatted {
    if (fileSizeBytes == null) return '';
    final kb = fileSizeBytes! / 1024;
    final mb = kb / 1024;
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    } else {
      return '${kb.toStringAsFixed(0)} KB';
    }
  }

  String get voiceDurationFormatted {
    if (voiceDurationSeconds == null) return '0:00';
    final minutes = voiceDurationSeconds! ~/ 60;
    final seconds = voiceDurationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}