import { ComponentFixture, TestBed } from '@angular/core/testing';
import { FormsModule } from '@angular/forms';
import { HttpClientTestingModule } from '@angular/common/http/testing';

import { Challenges } from './challenges';

describe('Challenges', () => {
  let component: Challenges;
  let fixture: ComponentFixture<Challenges>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [Challenges],
      imports: [FormsModule, HttpClientTestingModule],
    }).compileComponents();

    fixture = TestBed.createComponent(Challenges);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
