
class Stack<E> {
    private var list = [E]()
    private var m_size: Int = 0
    
    init() {
    }
    
    func push(_ item: E) {
        list.append(item)
        m_size += 1
    }
    
    func pop() -> E {
        m_size -= 1
        return list.removeLast()
    }
    
    func top() -> E {
        return list[m_size - 1]
    }
    
    func size() -> Int {
        return m_size
    }
    
    func empty() -> Bool {
        return m_size == 0
    }
}
