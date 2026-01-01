int main() {
    volatile int counter = 0;
    
    // The CPU simply executing this loop will cause the 
    // address lines to change, updating your 7-seg displays.
    while (1) {
        counter++;
        
        // Add some dummy math to make the loop larger
        // so the address changes are more interesting
        if (counter > 1000) {
            counter = 0;
        }
    }
    return 0;
}

