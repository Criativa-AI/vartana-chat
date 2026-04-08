const allElementsString = arr => {
  return arr.every(elem => typeof elem === 'string');
};

const allElementsNumbers = arr => {
  return arr.every(elem => typeof elem === 'number');
};

const formatArray = params => {
  if (params.length <= 0) {
    return [];
  }

  const primitivesOnly = params.every(
    elem =>
      elem === null ||
      elem === undefined ||
      typeof elem === 'string' ||
      typeof elem === 'number'
  );

  if (primitivesOnly) {
    return [...params];
  }

  return params.map(val => {
    if (val && typeof val === 'object' && 'id' in val) return val.id;
    return val;
  });
};

const generatePayloadForObject = item => {
  if (item.action_params.id) {
    item.action_params = [item.action_params.id];
  } else {
    item.action_params = [item.action_params];
  }
  return item.action_params;
};

const generatePayload = data => {
  const actions = JSON.parse(JSON.stringify(data));
  let payload = actions.map(item => {
    if (Array.isArray(item.action_params)) {
      item.action_params = formatArray(item.action_params);
    } else if (typeof item.action_params === 'object') {
      item.action_params = generatePayloadForObject(item);
    } else if (!item.action_params) {
      item.action_params = [];
    } else {
      item.action_params = [item.action_params];
    }
    return item;
  });
  return payload;
};

export default generatePayload;
