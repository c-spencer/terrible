scalar_walk = (v, walker) -> walker(v)
vector_walk = (v, walker) -> v.map(walker)

terribleWalkableAttributes =
  Program:
    body: vector_walk
  Operation:
    body: scalar_walk
  Vector: vector_walk
  List: vector_walk
  Hash: vector_walk
  HashPair:
    left: scalar_walk
    right: scalar_walk


walkerFactory = (walkableAttributes) ->
  walkProgramTree = (handlers, context, original_tree, args...) ->
    walkTree = (args...) ->
      selfApp = (tree) ->
        if handler = handlers[tree.type] or handlers.ANY
          result = handler.apply(null, [tree, walkTree, context, args...])
          if result != false
            return result

        if tree instanceof Array
          new_tree = tree.map(selfApp)
          new_tree.type = tree.type
        else if walks = walkableAttributes[tree.type]
          new_tree = {}
          for k, v of tree
            new_tree[k] = walks[k]?(v, selfApp) or v
        else
          new_tree = {}
          for k, v of tree
            new_tree[k] = v

        new_tree

    walkTree.apply(null, args)(original_tree)

module.exports = walkerFactory(terribleWalkableAttributes)
