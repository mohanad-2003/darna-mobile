/// Keeps [text], typically a phone number, in left-to-right order inside Arabic text,
/// where a leading "+" would otherwise jump to the wrong end.
String ltrIsolate(String text) =>
    '${String.fromCharCode(0x2066)}$text${String.fromCharCode(0x2069)}';
