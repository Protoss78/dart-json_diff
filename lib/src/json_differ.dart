part of shapeshift;

class JsonDiffer {
  Map<String,Object> leftJson, rightJson;
  
  JsonDiffer(leftString, rightString) {
    Object _leftJson = new JsonDecoder().convert(leftString);
    Object _rightJson = new JsonDecoder().convert(rightString);
    
    if (_leftJson is Map && _rightJson is Map) {
      leftJson = _leftJson;
      rightJson = _rightJson;
    } else {
      throw new FormatException("JSON must be a single object");
    }
  }
  
  void ensureIdentical(List<String> topLevelFields) {
    for (String field in topLevelFields) {
      if (!leftJson.containsKey(field)) {
        throw new UncomparableJsonException("left does not contain field '$field'");
      }
      if (!rightJson.containsKey(field)) {
        throw new UncomparableJsonException("right does not contain field '$field'");
      }
      if (leftJson[field] != rightJson[field]) {
        throw new UncomparableJsonException(
            "unequal values for field '$field': ${leftJson[field]} vs ${rightJson[field]}");
      }
    }
  }
  
  DiffNode diff() {
    Map<String,Object> added = new Map<String,Object>();
    Map<String,Object> removed = new Map<String,Object>();
    Map<String,Object> changed = new Map<String,Object>();
    
    DiffNode d = diffObjects(leftJson, rightJson);
    d.prune();
    return d;
  }
  
  DiffNode diffObjects(Map<String,Object> left, Map<String,Object> right) {
    DiffNode node = new DiffNode();
    left.forEach((String key, Object leftValue) {
      if (!right.containsKey(key)) {
        // [key] is missing from [right]
        node.removed[key] = leftValue;
        return;
      }
      
      Object rightValue = right[key];
      if (leftValue is List && rightValue is List) {
        /*Map<String,Object> leftListAsMap = new Map<String,Object>();
        Map<String,Object> rightListAsMap = new Map<String,Object>();
        for (int i = 0; i < leftValue.length; i++) {
          leftListAsMap[i.toString()] = leftValue[i];
        }
        for (int i = 0; i < rightValue.length; i++) {
          rightListAsMap[i.toString()] = rightValue[i];
        }
        node[key] = diffObjects(leftListAsMap, rightListAsMap);*/
        node[key] = diffLists(leftValue, rightValue);
      } else if (leftValue is Map && rightValue is Map) {
        node[key] = diffObjects(leftValue, rightValue);
      } else if (leftValue != rightValue) {
        // value is different between [left] and [right]
        node.changed[key] = [leftValue, rightValue];
      }
    });
    
    right.forEach((String key, Object value) {
      if (!left.containsKey(key)) {
        // [key] is missing from [left]
        node.added[key] = value;
      }
    });
    
    return node;
  }

  DiffNode diffLists(List<Object> left, List<Object> right) {
    DiffNode node = new DiffNode();
    int leftHand = 0;
    int leftFoot = 0;
    int rightHand = 0;
    int rightFoot = 0;
    while (leftHand < left.length && rightHand < right.length) {
      if (left[leftHand] != right[rightHand]) {
        // Walk hands up one at a time. Feet keep track of where we were.
        while (true) {
          rightHand++;
          if (rightHand < right.length && left[leftFoot] == right[rightHand]) {
            // Found it: the right elements at [rightFoot, rightHand-1] were added in right.
            for (int i=rightFoot; i<rightHand; i++) {
              node.added[i.toString()] = right[i];
            }
            rightFoot = rightHand;
            leftHand = leftFoot;
            break;
          }

          leftHand++;
          if (leftHand < left.length && left[leftHand] == right[rightFoot]) {
            // Found it: The left elements at [leftFoot, leftHand-1] were removed from left.
            for (int i=leftFoot; i<leftHand; i++) {
              node.removed[i.toString()] = left[i];
            }
            leftFoot = leftHand;
            rightHand = rightFoot;
            break;
          }

          if (leftHand >= left.length && rightHand >= right.length) { break; }
        }
      }
      leftHand++; rightHand++; leftFoot++; rightFoot++;
    }

    // Any new elements at the end of right.
    for (int i=rightHand; i<right.length; i++) {
      node.added[i.toString()] = right[i];
    }

    // Any removed elements at the end of left.
    for (int i=leftHand; i<left.length; i++) {
      node.removed[i.toString()] = left[i];
    }

    return node;
  }
}

class UncomparableJsonException implements Exception {
  final String msg;
  const UncomparableJsonException(this.msg);
  String toString() => 'UncomparableJsonException: $msg';
}