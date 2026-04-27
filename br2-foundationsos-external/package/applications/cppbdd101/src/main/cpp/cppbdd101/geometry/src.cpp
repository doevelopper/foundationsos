#include <iostream>

// Works with any type T which implements .name() or .area()
template <class T>
void describeArea(const T& obj){
     std::cout << "Shape is = " << obj.name() << std::endl;
     std::cout << "Area is  = " << obj.area() << std::endl;
     std::cout << "---------" << std::endl;
}

class Circle{
private:
    double m_radius;
public:
    Circle(double radius): m_radius(radius) {};
    double area() const {
       return 3.1415 * m_radius * m_radius;
    }
    const char* name() const {
        return "circle";
    }
};

class Square{
private:
   double m_side;
public:
   Square(double side): m_side(side) {};
   double area() const {
      return m_side * m_side;
   }
   const char* name() const {
      return "square";
   }
};

int main(){
    Square s(4.0);
    Circle c(3.0);
    describeArea(s);
    describeArea(c);
    return 0;
}

