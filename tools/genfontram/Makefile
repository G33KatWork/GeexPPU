TARGET = genfpntrom
OBJ = genfontrom.o

CFLAGS = -std=gnu99 -Wall
CXXFLAGS = -Wall
LDFLAGS = 

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $(OBJ) $(LDFLAGS)

clean:
	rm -f *.o
	rm -f $(TARGET)
