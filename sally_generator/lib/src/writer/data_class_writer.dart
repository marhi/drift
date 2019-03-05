import 'package:recase/recase.dart';
import 'package:sally_generator/src/model/specified_table.dart';

class DataClassWriter {
  final SpecifiedTable table;

  DataClassWriter(this.table);

  void writeInto(StringBuffer buffer) {
    buffer.write('class ${table.dartTypeName} {\n');

    // write individual fields
    for (var column in table.columns) {
      buffer.write('final ${column.dartTypeName} ${column.dartGetterName}; \n');
    }

    // write constructor with named optional fields
    buffer
      ..write(table.dartTypeName)
      ..write('({')
      ..write(table.columns
          .map((column) => 'this.${column.dartGetterName}')
          .join(', '))
      ..write('});');

    // Also write parsing factory
    _writeMappingConstructor(buffer);

    // And a convenience method to copy data from this class.
    _writeCopyWith(buffer);

    buffer.write('@override\n int get hashCode => ');

    if (table.columns.isEmpty) {
      buffer.write('identityHashCode(this); \n');
    } else {
      final fields = table.columns.map((c) => c.dartGetterName).toList();
      buffer..write(_calculateHashCode(fields))..write('; \n');
    }

    // override ==
    //    return identical(this, other) || (other is DataClass && other.id == id && ...)
    buffer
      ..write('@override\nbool operator ==(other) => ')
      ..write('identical(this, other) || (other is ${table.dartTypeName}');

    if (table.columns.isNotEmpty) {
      buffer
        ..write('&&')
        ..write(table.columns.map((c) {
          final getter = c.dartGetterName;

          return 'other.$getter == $getter';
        }).join(' && '));
    }

    // finish overrides method and class declaration
    buffer.write(');\n}');
  }

  void _writeMappingConstructor(StringBuffer buffer) {
    final dataClassName = table.dartTypeName;

    buffer.write(
        'factory $dataClassName.fromData(Map<String, dynamic> data, GeneratedDatabase db) {\n');

    final dartTypeToResolver = <String, String>{};

    final types = table.columns.map((c) => c.dartTypeName).toSet();
    for (var usedType in types) {
      // final intType = db.typeSystem.forDartType<int>();
      final resolver = '${ReCase(usedType).camelCase}Type';
      dartTypeToResolver[usedType] = resolver;

      buffer
          .write('final $resolver = db.typeSystem.forDartType<$usedType>();\n');
    }

    // finally, the mighty constructor invocation:
    buffer.write('return $dataClassName(');

    for (var column in table.columns) {
      // id: intType.mapFromDatabaseResponse(data["id])
      final getter = column.dartGetterName;
      final resolver = dartTypeToResolver[column.dartTypeName];
      final typeParser =
          '$resolver.mapFromDatabaseResponse(data[\'${column.name.name}\'])';

      buffer.write('$getter: $typeParser,');
    }

    buffer.write(');}\n');
  }

  void _writeCopyWith(StringBuffer buffer) {
    final dataClassName = table.dartTypeName;

    buffer.write('$dataClassName copyWith({');
    for (var i = 0; i < table.columns.length; i++) {
      final column = table.columns[i];
      final last = i == table.columns.length - 1;

      buffer.write('${column.dartTypeName} ${column.dartGetterName}');
      if (!last) {
        buffer.write(',');
      }
    }

    buffer.write('}) => $dataClassName(');

    for (var column in table.columns) {
      // we also have a method parameter called getter, so we can use
      // field: field ?? this.field
      final getter = column.dartGetterName;
      buffer.write('$getter: $getter ?? this.$getter,');
    }

    buffer.write(');');
  }

  /// Recursively creates the implementation for hashCode of the data class,
  /// assuming it has at least one field. When it has one field, we just return
  /// the hash code of that field. Otherwise, we multiply it with 31 and add
  /// the hash code of the next field, and so on.
  String _calculateHashCode(List<String> fields) {
    if (fields.length == 1) {
      return '${fields.last}.hashCode';
    } else {
      final last = fields.removeLast();
      final innerHash = _calculateHashCode(fields);

      return '($innerHash) * 31 + $last.hashCode';
    }
  }
}
